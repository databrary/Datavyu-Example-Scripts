# Updated 4.24.20

require 'Datavyu_API.rb'

begin
    ec = getColumn("eye_contact")
    slcol = getColumn("speaker_listener")
    greetcol = getColumn("greeting")

    [ec, slcol, greetcol].each do |col|
        col.set_hidden(true)
        setColumn(col)
    end

    makeReliability("speaker_listener_2", slcol, 1, "onset", "offset")
    ec2 = createColumn("eye_contact_2")
    setColumn(ec2)
    makeReliability("greeting_2", greetcol, 1, "onset", "offset", "ordinal")
end