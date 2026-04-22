# Purpose: This script processes and imports transcript files into Datavyu. 
# 
# Supported Formats:
#   - WebVTT (.vtt)
#   - SubRip (.srt) [planned]
#   - Plain Text (.txt) [planned]
#
# Features:
#   - File format validation
#   - Timestamp conversion
#   - Quality assurance workflow
#   - Support for multiple subtitle formats [planned]
#   - Optimized performance for large files
#   - Dynamic chunk sizing based on file size
# 
# Usage:
#   1. Run script
#   2. Select subtitle/transcript file when prompted
#   3. Script will create necessary columns in Datavyu:
#      - transcript_original: Contains original transcription content
#      - transcript_QA: For marking various types of errors
#      - transcript_clean: For adding speaker labels to transcription
#      - transcript_initials: For coder identification
#      - transcript_notes: For additional observations
# Authors: Aaron G. Beckner & Trinity Wang
# 02-27-2025: Added flexible timestamp detection
# 01-14-2025: Added comments and made more generic

# Revised by Van T. Pham for SPACE 2024 play coding
# Last edited: 01-21-2025
# Optimized version: 02-27-2025

require 'Datavyu_API.rb'

# Configuration constants
SUPPORTED_FORMATS = {
  'vtt' => 'WebVTT Subtitles'
  # Add additional formats here as needed:
  # 'srt' => 'SubRip Subtitles',
  # 'txt' => 'Plain Text Transcripts'
}

# Column configurations
COLUMN_CONFIGS = {
  transcript_original: {
    name: 'transcript_original',
    codes: ['content'],
    required: true
  },
  qa: {
    name: 'transcript_QA',
    codes: ['OnsetError', 'ContentError', 'OmittedUtterance', 'HallucinatedUtterance', 'SpeakerChange'], # quality assurance error codes
    required: true
  },
  transcript_clean: {
    name: 'transcript_clean',
    codes: ['speaker', 'content'],  # Codes for speaker labeling and transcription content
    required: true
  },
  initials: {
    name: 'transcript_initials',
    codes: ['coder_initials'], # Optional Coder initials column
    required: false
  },
  notes: {
    name: 'transcript_notes',
    codes: ['notes'],
    required: false
  }
}

# Base ratio for determining chunk size (adjust as needed)
# For every 10 cells, use chunk size of 1
BASE_RATIO = 10.0
# Minimum and maximum chunk sizes to ensure reasonable processing
MIN_CHUNK_SIZE = 10
MAX_CHUNK_SIZE = 100

begin
  # Import Java classes for GUI file selection
  java_import javax.swing.JFileChooser
  java_import javax.swing.filechooser.FileNameExtensionFilter
  java_import javax.swing.JFrame
  java_import javax.swing.JOptionPane

  # Sets up the file chooser dialog
  def setup_file_chooser
    frame = JFrame.new("Import Transcript")
    frame.setDefaultCloseOperation(JFrame::DISPOSE_ON_CLOSE)
    frame.setSize(200, 200)
    frame.setLocationRelativeTo(nil)
    
    jfc = JFileChooser.new
    jfc.setAcceptAllFileFilterUsed(false)
    jfc.setMultiSelectionEnabled(false)
    jfc.setDialogTitle('Select transcript file to import')
    
    SUPPORTED_FORMATS.each do |format, description|
      extensions = [format].to_java(:String)
      filter = FileNameExtensionFilter.new(description, extensions)
      jfc.addChoosableFileFilter(filter)
    end
    
    [frame, jfc]
  end

  # Validates that the selected file has a supported format
  def validate_file_format(file_path)
    extension = File.extname(file_path)[1..-1]
    raise "Unsupported file format: .#{extension}" unless SUPPORTED_FORMATS.key?(extension)
    true
  end

  # Optimize timestamp parsing for better performance
  def parse_timestamp(time_str)
    # Handle HH:MM:SS.mmm format
    if time_str.match(/^(\d{2}):(\d{2}):(\d{2})\.(\d{3})$/)
      hours = $1.to_i
      minutes = $2.to_i
      seconds = $3.to_i
      milliseconds = $4.to_i
      
      return (hours * 3600000) + (minutes * 60000) + (seconds * 1000) + milliseconds
    # Handle MM:SS.mmm format (no hours)
    elsif time_str.match(/^(\d{2}):(\d{2})\.(\d{3})$/)
      minutes = $1.to_i
      seconds = $2.to_i
      milliseconds = $3.to_i
      
      return (minutes * 60000) + (seconds * 1000) + milliseconds
    else
      raise "Invalid timestamp format: #{time_str}. Expected format: HH:MM:SS.mmm or MM:SS.mmm"
    end
  end

  # Pre-process the content to extract words and timestamps more efficiently
  def process_content(content)
    # Remove WEBVTT header if present
    content.shift if content.first && content.first.strip == 'WEBVTT'
    
    timestamps = []
    words = []
    current_timestamp = nil
    
    content.each do |line|
      line = line.strip
      next if line.empty?
      
      if line.include?("-->")
        onset_str, offset_str = line.split('-->').map(&:strip)
        current_timestamp = {
          onset: parse_timestamp(onset_str),
          offset: parse_timestamp(offset_str)
        }
      elsif line.match(/^\d+$/)
        # Skip cue numbers (commonly found in VTT files)
        next
      elsif current_timestamp && line.match(/^[a-zA-Z]/)
        # Only add lines that start with letters and have a valid timestamp
        timestamps << current_timestamp
        words << line
      end
    end
    
    [words, timestamps]
  end

  # Calculate optimal chunk size based on number of cells
  def calculate_chunk_size(total_cells)
    # Use the ratio of 1 chunk per 10 cells as basis
    chunk_size = (total_cells / BASE_RATIO).ceil
    
    # Enforce minimum and maximum chunk sizes
    chunk_size = [chunk_size, MIN_CHUNK_SIZE].max
    chunk_size = [chunk_size, MAX_CHUNK_SIZE].min
    
    puts "Calculated optimal chunk size: #{chunk_size} for #{total_cells} cells"
    chunk_size
  end

  # Create columns in batches for better performance
  def create_columns(words, timestamps)
    columns = {}
    
    # First create all columns
    COLUMN_CONFIGS.each do |type, config|
      if config[:required]
        columns[type] = new_column(config[:name], *config[:codes])
      end
    end
    
    # Calculate total number of entries and dynamic chunk size
    total_entries = words.size
    chunk_size = calculate_chunk_size(total_entries)
    total_chunks = (total_entries.to_f / chunk_size).ceil
    
    puts "Processing #{total_entries} entries in #{total_chunks} chunks with chunk size of #{chunk_size}..."
    
    # Process in chunks
    (0...total_chunks).each do |chunk_idx|
      start_idx = chunk_idx * chunk_size
      end_idx = [start_idx + chunk_size, total_entries].min
      
      chunk_range = (start_idx...end_idx)
      chunk_words = words[chunk_range]
      chunk_timestamps = timestamps[chunk_range]
      
      puts "Processing chunk #{chunk_idx + 1}/#{total_chunks} (entries #{start_idx + 1}-#{end_idx})..."
      
      # Process each column type for this chunk
      COLUMN_CONFIGS.each do |type, config|
        next unless config[:required]
        column = columns[type]
        
        chunk_words.each_with_index do |word, i|
          cell = column.make_new_cell
          timestamp = chunk_timestamps[i]
          
          # Set onset and offset
          cell.change_code('onset', timestamp[:onset])
          cell.change_code('offset', timestamp[:offset])
          
          # Set content based on column type
          case type
          when :transcript_original
            cell.change_code('content', word)
          when :transcript_clean
            cell.change_code('content', word)
            cell.change_code('speaker', '')  # Initialize speaker field empty
          when :qa
            # Initialize QA codes as empty
            config[:codes].each do |code|
              cell.change_code(code, '')
            end
          when :initials
            cell.change_code('coder_initials', '')
          when :notes
            cell.change_code('notes', '')
          end
        end
      end
    end
    
    puts "Setting columns in Datavyu..."
    columns.each do |_, column|
      set_column(column)
    end
  end

  # Show progress dialog
  def show_progress_dialog(message)
    JOptionPane.showMessageDialog(nil, message, "Progress", JOptionPane::INFORMATION_MESSAGE)
  end

  # Main execution flow
  puts "Starting transcript import..."

  # Setup and show file chooser
  frame, jfc = setup_file_chooser
  frame.setVisible(true)
  
  result = jfc.showOpenDialog(frame)
  frame.dispose

  if result != JFileChooser::APPROVE_OPTION
    puts "No file selected. Aborting."
    return
  end

  file_path = jfc.getSelectedFile.getPath
  validate_file_format(file_path)

  puts "Reading file: #{file_path}"
  show_progress_dialog("Reading file. Please wait...")
  
  # Read file content
  content = File.readlines(file_path)
  
  puts "Processing content..."
  show_progress_dialog("Processing transcript. This may take a moment for large files...")
  
  # Process file content
  words, timestamps = process_content(content)
  
  if words.empty? || timestamps.empty?
    puts "No valid transcript entries found. Check file format."
    show_progress_dialog("No valid transcript entries found. Check file format.")
    return
  end
  
  puts "Creating Datavyu columns with #{words.size} entries..."
  show_progress_dialog("Creating Datavyu columns with #{words.size} entries. Please wait...")
  
  # Create columns with dynamically sized batched processing
  create_columns(words, timestamps)

  puts "Import completed successfully!"
  show_progress_dialog("Import completed successfully!")

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace if ENV['DEBUG']
  JOptionPane.showMessageDialog(nil, "Error: #{e.message}", "Import Error", JOptionPane::ERROR_MESSAGE)
end
