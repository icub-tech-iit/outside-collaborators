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
def get_repo_invitations(repo)
    loop do
        check_and_wait_until_reset
        $client.repository_invitations(repo)
        rate_limit = $client.rate_limit
        if rate_limit.remaining > 0 then
            break
        end
    end
      
    invitations = []

    last_response = $client.last_response
    data = last_response.data
    data.each { |i| invitations << {"id" => i.id,
                                    "invitee" => i.invitee.login,
                                    "permissions" => i.permissions} }
      
    until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        data = last_response.data
        data.each { |i| invitations << {"id" => i.id,
                                        "invitee" => i.invitee.login,
                                        "permissions" => i.permissions} }
    end

    return invitations
end


#########################################################################################
def get_repo_collaborators(repo)
    loop do
        check_and_wait_until_reset
        $client.collaborators(repo)
        rate_limit = $client.rate_limit
        if rate_limit.remaining > 0 then
            break
        end
    end

    collaborators = []
      
    last_response = $client.last_response
    data = last_response.data
    data.each { |c| collaborators << "#{c.login}" }

    until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        data = last_response.data
        data.each { |c| collaborators << "#{c.login}" }
    end

    return collaborators
end


#########################################################################################
def add_repo_collaborator(repo, user, auth)
    check_and_wait_until_reset
    begin
        $client.user(user)
    rescue
        puts "- Requested action for not existing user \"#{user}\" ❌"
    else
        check_and_wait_until_reset
        if $client.org_member?($org, user) then
            puts "- Requested action for organization member \"#{user}\" ❌"
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
                        print "- Skipping invitee \"#{user}\" with permissions \"#{auth_}\""
                    else
                        print "- Updating invitee \"#{user}\" with permissions \"#{auth_}\""
                        if !auth_.casecmp?(auth) then
                            print " (\"#{auth}\" is not available ⚠)"
                        end
                        print "\n"
                        check_and_wait_until_reset
                        $client.update_repository_invitation(repo, invitation["id"], permission: auth_)
                    end
                    return
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
            rescue
                puts " - problem detected ❌"
            end
            print "\n"
        end
    end
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
        # add collaborators
        if repo_metadata then
            repo_metadata.each { |user, props|
                type = props["type"]
                permissions = props["permissions"]
                if (type.casecmp?("user")) then
                    add_repo_collaborator(repo_full_name, user, permissions)
                elsif (type.casecmp?("group")) then
                    if groups.key?(user) then
                        puts "- Handling group \"#{user}\" 👥"
                        groups[user].each { |subuser|
                            if repo_metadata.key?(subuser) then
                                puts "- Detected group user \"#{subuser}\" handled individually"
                            else
                                add_repo_collaborator(repo_full_name, subuser, permissions)
                            end
                        }
                    else
                        puts "- Unrecognized group \"#{user}\" ❌"
                    end
                else
                    puts "- Unrecognized type \"#{type}\" ❌"
                end
            }
        end

        # remove collaborators no longer requested
        get_repo_collaborators(repo_full_name).each { |user|
            check_and_wait_until_reset
            if !$client.org_member?($org, user) then
                if !repo_member(repo_metadata, groups, user) then
                    puts "- Removing collaborator \"#{user}\""
                    check_and_wait_until_reset
                    $client.remove_collaborator(repo_full_name, user)
                end
            end
        }

        # remove pending invitations of collaborators no longer requested
        get_repo_invitations(repo_full_name).each { |invitation|
            invitee = invitation["invitee"]
            check_and_wait_until_reset
            if !$client.org_member?($org, invitee) then
                if !repo_member(repo_metadata, groups, invitee) then
                    puts "- Removing invitee \"#{invitee}\""
                    check_and_wait_until_reset
                    $client.delete_repository_invitation(repo_full_name, invitation["id"])
                end
            end
        }

        puts "...done with \"#{repo_full_name}\" ✔"
    else
        puts "Repository \"#{repo_full_name}\" does not exist ❌"
    end
    puts ""
}
