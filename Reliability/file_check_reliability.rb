# Updated 4.24.20

require 'Datavyu_API.rb'

        puts ("EYE CONTACT: \n")

        main_col = getColumn("eye_contact")
        rel_col = getColumn("eye_contact_2")

        if (rel_col == nil) or (rel_col.cells == nil)
            puts file.to_s + " is not coded for reliability\n\n"
            next
        end
        
        main_col_times = Array.new

        for mc in main_col.cells
            main_col_times << [mc.onset, mc.offset] # << appends to array
        end

        rel_col_times = Array.new

        for rc in rel_col.cells
            rel_col_times << [rc.onset, rc.offset]
        end
            
        total_successes = 0 
        total_rel_cells = 0
        errors = Array.new
        not_errors = Array.new

        for cell in rel_col.cells
            total_rel_cells = total_rel_cells + 1
            errors << cell.onset
        end 

        for pair1 in rel_col_times
            for pair2 in main_col_times
                if ((pair1[0] - pair2[0]).abs <= 2000) and ((pair1[1] - pair2[1]).abs <= 2000)
                    total_successes = total_successes + 1
                    not_errors << pair1[0]
                    break
                end
            end
        end 

        errors = errors - not_errors
        i = 1

        for error in errors
            error = (error/1000.0)
            puts "(" + i.to_s + ") No match for reliability cell at onset time: " + error.to_s + " seconds\n\n"
            i = i + 1
        end

        total_rel_cells = total_rel_cells.to_f
        total_successes = total_successes.to_f

        percent_reliability1 = (total_successes / total_rel_cells) * 100

        print "Total number of reliability cells: " + total_rel_cells.to_s + "\n"
        print "Total number of reliability cells with matching times: " + total_successes.to_s + "\n"
        puts "Percentage of reliable cells: " + percent_reliability1.to_s + "% \n"

        total_duration_main_col = 0.0
        total_duration_rel_col = 0.0

        for cell in main_col.cells
            duration = (cell.offset - cell.onset)
            total_duration_main_col = total_duration_main_col + duration
        end

        total_duration_main_col = total_duration_main_col/1000.0

        print "Total duration reported for eye_contact: " + total_duration_main_col.to_s + " seconds.\n"

        for cell in rel_col.cells
            duration = (cell.offset - cell.onset)
            total_duration_rel_col = total_duration_rel_col + duration
        end

        total_duration_rel_col = total_duration_rel_col/1000.0

        print "Total duration reported for eye_contact_2: " + total_duration_rel_col.to_s + " seconds.\n"

        peer_col = getColumn("peer")
        peer_times = Array.new
        for cell in peer_col.cells
            peer_times << [cell.onset, cell.offset]
        end 

        puts "\n--------------------------------------------------------------------------------------------------------- \n"
        puts "\nSPEAKER_LISTENER: \n "
        s_l_col = getColumn("speaker_listener")
        rel_col = getColumn("speaker_listener_2")
        match_arg = "onset"
        time_tol = 5 
        checkReliability(s_l_col, rel_col, match_arg, time_tol)

        s_args_main = 0.0
        s_args_rel = 0.0
        l_args_main = 0.0
        l_args_rel = 0.0

        for cell in s_l_col.cells
            if cell.argvals[0] == "S"
                s_args_main = s_args_main + 1
            end
            if cell.argvals[0] == "L"
                l_args_main = l_args_main + 1
            end
        end

        for cell in rel_col.cells
            if cell.argvals[0] == "S"
                s_args_rel = s_args_rel + 1
            end
            if cell.argvals[0] == "L"
                l_args_rel = l_args_rel + 1
            end
        end

        rel_speaker_only = 0.0
        rel_listener_only = 0.0

        rel_speaker_only = ((s_args_main/s_args_rel)*100)
        rel_listener_only = ((l_args_main/l_args_rel)*100)

        if s_args_main > s_args_rel
            rel_speaker_only = 100
        end
        if l_args_main > l_args_rel
            rel_listener_only = 100
        end

        puts "\nPercent agreement for SPEAKER ONLY: " + rel_speaker_only.to_s + "% \n"
        puts "Percent agreement for LISTENER ONLY: " + rel_listener_only.to_s + "%\n" # Counting cells method

        main_col = getColumn("speaker_listener")
        rel_col = getColumn("speaker_listener_2")
        
        main_col_times = Array.new
        for mc in main_col.cells
            if (mc.argvals[0] == "L")
                main_col_times << [mc.onset, mc.offset] 
            end
        end
        rel_col_times = Array.new
        for rc in rel_col.cells
            if (rc.argvals[0] == "L")
                rel_col_times << [rc.onset, rc.offset]
            end
        end
            
        # Now check each pair in rel times to see if they are within the range of one of the pairs in main col times using accumulators

        total_successes = 0 
        total_rel_cells = 0

        for cell in rel_col.cells
            if cell.argvals[0] == "L"
                total_rel_cells = total_rel_cells + 1
            end
        end 

        for pair1 in rel_col_times
            for pair2 in main_col_times
                if (pair1[0] - pair2[0]).abs <= 2000 and (pair1[1] - pair2[1]).abs <= 2000
                    total_successes = total_successes + 1
                    break
                end
            end
        end 

        total_rel_cells = total_rel_cells.to_f
        total_successes = total_successes.to_f

        percent_reliability_listener = (total_successes / total_rel_cells) * 100
        puts "Percentage of reliable cells for listener (using two-second method): " + percent_reliability_listener.to_s + "% \n"

        # End Speaker_Listener ------------------------------------------------------------------------------------------------------------------------------

        # Begin Greeting_goodbye ----------------------------------------------------------------------------------------------------------------------------

        puts "\n-------------------------------------------------------------------------------------------------\n"
        puts "\nGREETING\n"
        main_col = getColumn("greeting")
        rel_col = getColumn("greeting_2")

        if (main_col == nil) or (rel_col == nil)
            main_col == getColumn("greeting_goodbye")
            rel_col == getColumn("greeting_goodbye_2")
        end

        for cell in main_col.cells
            if cell.onset > 60000
                deleteCell(cell)
                setColumn(main_col)
            end
        end

        for cell in rel_col.cells
            if cell.onset > 60000
                deleteCell(cell)
                setColumn(rel_col)
            end
        end
            
        checkReliability(main_col, rel_col, "onset", 10)
        puts "\n\n\n\n"
# End Greeting_goodbye ------------------------------------------------------------------------------------------------------------------------------

# Excel Output: Comma scripted values, copy in one cell --> data --> text to columns --> delimit by columns -----------------------------------------
