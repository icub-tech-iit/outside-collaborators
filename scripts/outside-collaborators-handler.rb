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
def get_repo_collaborators(repo)
    loop do
        check_and_wait_until_reset
        begin
            $client.collaborators(repo)
        rescue
        else
            break
        end
    end

    collaborators = []
    last_response = $client.last_response
    loop do
        data = last_response.data
        data.each { |c| collaborators << "#{c.login}" }
        if last_response.rels[:next].nil?
            break
        else
            last_response = last_response.rels[:next].get
        end
    end

    return collaborators
end


#########################################################################################
def add_repo_collaborator(repo, user, auth)
    check_and_wait_until_reset
    begin
        login = $client.user(user).login
    rescue
        puts "- Requested action for not existing user \"#{user}\" ❌"
        return false
    else
        if user != login then
            puts "- \"#{user}\" shall be provided as \"#{login}\" ❌"
            exit 1
        end

        check_and_wait_until_reset
        if $client.org_member?($org, user) then
            puts "- Requested action for organization member \"#{user}\" ❌"
            return false
        else
            if auth.nil? then
                auth = ""
            end

            # bind authorization within available options
            auth_ = auth
            if !auth_.casecmp?("admin") && !auth_.casecmp?("maintain") &&
               !auth_.casecmp?("write") && !auth_.casecmp?("triage") &&
               !auth_.casecmp?("read") then
                auth_ = "read"
            end

            # update pending invitation
            get_repo_invitations(repo).each { |invitation|
                if invitation["invitee"].casecmp?(user) then
                    if invitation["permissions"].casecmp?(auth_) then
                        puts "- Skipping invitee \"#{user}\" with permissions \"#{auth_}\""
                        return true
                    else
                        puts "- Removing invitee \"#{user}\""
                        check_and_wait_until_reset
                        $client.delete_repository_invitation(repo, invitation["id"])
                    end
                end
            }

            # remap permissions to comply w/ REST API
            auth__ = auth_
            if auth__.casecmp?("read") then
                auth__ = "pull"
            elsif auth__.casecmp?("write") then
                auth__ = "push"
            end

            # handle: invitation, update
            check_and_wait_until_reset
            if $client.collaborator?(repo, user) then
                print "- Updating collaborator \"#{user}\" with permissions \"#{auth_}\""
            else
                print "- Inviting collaborator \"#{user}\" with permissions \"#{auth_}\""
            end
            if !auth_.casecmp?(auth) then
                print " (\"#{auth}\" is not available ⚠)"
            end
            check_and_wait_until_reset
            begin
                $client.add_collaborator(repo, user, permission: auth__)
            rescue StandardError => e
                puts " - problem detected: #{e.inspect} ❌"
                return false
            end
            print "\n"
        end
    end

    return true
end


#########################################################################################
# main

# retrieve information from files
groups = get_entries("../groups")
repos = get_entries("../repos")

# remove empty groups
groups.compact!

has_errors = false

# cycle over repos
repos.each { |repo_name, repo_metadata|
    repo_full_name = $org + "/" + repo_name
    puts "Processing automated repository \"#{repo_full_name}\"..."

    check_and_wait_until_reset
    if $client.repository?(repo_full_name) then
        # check if archived
        if !$client.repository(repo_full_name).archived then
            # add collaborators
            if repo_metadata then
                repo_metadata.each { |user, props|
                    type = props["type"]
                    permissions = props["permissions"]
                    if (type.casecmp?("user")) then
                        if !add_repo_collaborator(repo_full_name, user, permissions) then
                            has_errors = true
                        end
                    elsif (type.casecmp?("group")) then
                        if groups.key?(user) then
                            puts "- Handling group \"#{user}\" 👥"
                            groups[user].each { |subuser|
                                if repo_metadata.key?(subuser) then
                                    puts "- Detected group user \"#{subuser}\" handled individually"
                                elsif !add_repo_collaborator(repo_full_name, subuser, permissions) then
                                    has_errors = true
                                end
                            }
                        else
                            puts "- Unrecognized group \"#{user}\" ❌"
                            has_errors = true
                        end
                    else
                        puts "- Unrecognized type \"#{type}\" ❌"
                        has_errors = true
                    end
                }
            end

            # remove collaborators no longer requested
            get_repo_collaborators(repo_full_name).each { |user|
                check_and_wait_until_reset
                if !$client.org_member?($org, user) &&
                   !repo_member(repo_metadata, groups, user) then
                    puts "- Removing collaborator \"#{user}\""
                    check_and_wait_until_reset
                    $client.remove_collaborator(repo_full_name, user)
                end
            }

            # remove pending invitations of collaborators no longer requested
            get_repo_invitations(repo_full_name).each { |invitation|
                invitee = invitation["invitee"]
                check_and_wait_until_reset
                if !$client.org_member?($org, invitee) &&
                   !repo_member(repo_metadata, groups, invitee) then
                    puts "- Removing invitee \"#{invitee}\""
                    check_and_wait_until_reset
                    $client.delete_repository_invitation(repo_full_name, invitation["id"])
                end
            }

            puts "...done with \"#{repo_full_name}\" ✔"
        else
            puts "Skipping archived repository \"#{repo_full_name}\" ⚠️"
        end
    else
        puts "Repository \"#{repo_full_name}\" does not exist ❌"
        has_errors = true
    end
    puts ""
}

if has_errors then 
    puts "Errors detected: inspect the log"
    exit 1
end
