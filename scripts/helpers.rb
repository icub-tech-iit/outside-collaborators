#########################################################################################
def check_and_wait_until_reset
    rate_limit = $client.rate_limit
    if rate_limit.remaining == 0 then
        reset_secs = rate_limit.resets_in
        reset_mins = reset_secs / 60
        puts "⏳ GitHub API Rate Limit will reset at #{rate_limit.resets_at} in #{reset_mins} mins"
        reset_secs = reset_secs + 60
        wait(reset_secs)
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
