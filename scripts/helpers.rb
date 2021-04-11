# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>


#########################################################################################
def check_and_wait_until_reset
    rate_limit = $client.rate_limit
    if rate_limit.remaining == 0 then
        reset_secs = rate_limit.resets_in + 60
        reset_mins = reset_secs / 60
        puts "⏳ We hit the GitHub API rate limit; reset will occur at #{rate_limit.resets_at}"
        puts "⏳ Process suspended for #{reset_mins} mins"
        sleep(reset_secs)
        puts "⏳ Process recovered ✔"
    end
end


#########################################################################################
def get_entries(dirname)
    files = Dir[dirname + "/*.yml"]
    files << Dir[dirname + "/*.yaml"]

    entries = {}
    if files then
        files.each { |file|
            if !file.empty? then
                entries.merge!(YAML.load_file(file))
            end
        }
    end

    return entries
end
