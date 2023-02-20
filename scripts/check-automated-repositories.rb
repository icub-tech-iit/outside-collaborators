#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>


#########################################################################################
# deps
require 'octokit'
require 'yaml'
require './helpers'


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
def check_user(user, permissions)
    check_and_wait_until_reset
    begin
        login = $client.user(user).login
    rescue
        puts "- \"#{user}\" does not exist ❌"
        exit 1
    else
        if user != login then
            puts "- \"#{user}\" shall be provided as \"#{login}\" ❌"
            exit 1
        end

        check_and_wait_until_reset
        if $client.org_member?($org, user) then
            puts "- \"#{user}\" is also organization member ❌"
            exit 1
        elsif !permissions.casecmp?("admin") && !permissions.casecmp?("maintain") &&
            !permissions.casecmp?("write") && !permissions.casecmp?("triage") &&
            !permissions.casecmp?("read") then
            puts "- \"#{user}\" with unavailable permissions \"#{permissions}\" ❌"
            exit 1
        else
            puts "- \"#{user}\" with permissions \"#{permissions}\""
        end
    end
end


#########################################################################################
# main

# retrieve information from files
groups = get_entries("../groups")
repos = get_entries("../repos")

# remove empty groups
groups.compact!

# cycle over repos
repos.each { |repo_name, repo_metadata|
    repo_full_name = $org + "/" + repo_name
    puts "Processing automated repository \"#{repo_full_name}\"..."

    check_and_wait_until_reset
    if $client.repository?(repo_full_name) then
        # check if archived
        if !$client.repository(repo_full_name).archived then
            # check collaborators
            if repo_metadata then
                repo_metadata.each { |user, props|
                    type = props["type"]
                    permissions = props["permissions"]
                    if (type.casecmp?("user")) then
                        check_user(user, permissions)
                    elsif (type.casecmp?("group")) then
                        if groups.key?(user) then
                            puts "- Listing collaborators in group \"#{user}\" 👥"
                            groups[user].each { |subuser|
                                if repo_metadata.key?(subuser) then
                                    puts "- Detected group user \"#{subuser}\" handled individually"
                                else
                                    check_user(subuser, permissions)
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
            puts "Skipping archived repository \"#{repo_full_name}\" ⚠️"
        end
    else
        puts "Repository \"#{repo_full_name}\" does not exist ❌"
        exit 1
    end
    puts ""
}
