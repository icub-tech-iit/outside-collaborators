#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>


#########################################################################################
# deps
require 'octokit'
require 'yaml'


#########################################################################################
# global vars
$org = ENV['OUTSIDE_COLLABORATORS_GITHUB_ORG']
$client = Octokit::Client.new :access_token => ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']


#########################################################################################
# traps
Signal.trap("INT") {
  exit 2
}

Signal.trap("TERM") {
  exit 2
}


#########################################################################################
def check_and_wait_until_reset
    rate_limit = $client.rate_limit
    if rate_limit.remaining == 0 then
        reset_secs = rate_limit.resets_in
        reset_mins = reset_secs / 60
        puts "⏳ GitHub API Rate Limit will reset at #{rate_limit.resets_at} in #{reset_mins} mins"
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


#########################################################################################
def check_user(user, permission)
    check_and_wait_until_reset
    begin
        $client.user(user)
    rescue
        puts "- \"#{user}\" does not exist ❌"
        exit 1
    else
        check_and_wait_until_reset
        if $client.org_member?($org, user) then
            puts "- \"#{user}\" is also organization member ❌"
            exit 1
        elsif !permission.casecmp?("admin") && !permission.casecmp?("maintain") &&
            !permission.casecmp?("write") && !permission.casecmp?("triage") &&
            !permission.casecmp?("read") then
            puts "- \"#{user}\" with unavailable permission \"#{permission}\" ❌"
            exit 1
        else
            puts "- \"#{user}\" with permission \"#{permission}\""
        end
    end
end


#########################################################################################
# main

# retrieve information from files
groups = get_entries("../groups")
repos = get_entries("../repos")

# cycle over repos
repos.each { |repo_name, repo_metadata|
    repo_full_name = $org + "/" + repo_name
    puts "Processing automated repository \"#{repo_full_name}\"..."

    check_and_wait_until_reset
    if $client.repository?(repo_full_name) then
        # check collaborators
        if repo_metadata then
            repo_metadata.each { |user, props|
                type = props["type"]
                permission = props["permission"]
                if (type.casecmp?("user")) then
                    check_user(user, permission)
                elsif (type.casecmp?("group")) then
                    if groups.key?(user) then
                        puts "- Listing collaborators in group \"#{user}\" 👥"
                        groups[user].each { |subuser|
                            if repo_metadata.key?(subuser) then
                                puts "- Detected group user \"#{subuser}\" handled individually"
                            else
                                check_user(subuser, permission)
                            end
                        }
                    else
                        puts "- Unrecognized group \"#{user}\" ❌"
                        exit 1
                    end
                else
                    puts "- Unrecognized type \"#{type}\" ❌"
                    exit 1
                end
            }
        end

        puts "...done with \"#{repo_full_name}\" ✔"
    else
        puts "Repository \"#{repo_full_name}\" does not exist ❌"
        exit 1
    end
    puts ""
}
