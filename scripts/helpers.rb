# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>


#########################################################################################
def check_and_wait_until_reset
    rate_limit = $client.rate_limit
    if rate_limit.remaining <= 10 then
        reset_secs = rate_limit.resets_in + 60
        reset_mins = reset_secs / 60
        puts ""
        puts "⏳ We hit the GitHub API rate limit; reset will occur at #{rate_limit.resets_at}"
        puts "⏳ Process suspended for #{reset_mins} mins"
        sleep(reset_secs)
        puts "⏳ Process recovered ✔"
        puts ""
    end
end


#########################################################################################
def get_entries(dirname)
    files = Dir[dirname + "/*.yml"]
    files = files + Dir[dirname + "/*.yaml"]

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


#########################################################################################
def get_repo_invitations(repo)
    loop do
        check_and_wait_until_reset
        begin
            $client.repository_invitations(repo)
        rescue
        else
            break
        end
    end
      
    invitations = []
    last_response = $client.last_response
    loop do
        data = last_response.data
        data.each { |i| invitations << {"id" => i.id,
                                        "invitee" => i.invitee.login,
                                        "permissions" => i.permissions,
                                        "expired" => i.expired} }
        if last_response.rels[:next].nil?
            break
        else
            last_response = last_response.rels[:next].get
        end
    end

    return invitations
end


#########################################################################################
def repo_member(repo_metadata, groups, user)
    if repo_metadata then
        if repo_metadata.key?(user) then
            return true
        else
            repo_metadata.each { |item, props|
                if (props["type"].casecmp?("group")) then
                    if groups.key?(item) then
                        if groups[item].include?(user)
                            return true
                        end
                    end
                end
            }
        end
    end
    return false
end
