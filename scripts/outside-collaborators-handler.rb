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
$metadata_filename = ENV['OUTSIDE_COLLABORATORS_METADATA_FILENAME']
$client = Octokit::Client.new :access_token => ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']
$wait = 60


#########################################################################################
# traps
Signal.trap("INT") {
  exit 2
}

Signal.trap("TERM") {
  exit 2
}


#########################################################################################
def get_repo_metadata(repo)
    begin
        repo_metadata = $client.contents(repo.full_name, :path => $metadata_filename)
    rescue
        return {}
    else
        return {repo.full_name => YAML.load(Base64.decode64(repo_metadata.content))}
    end
end


#########################################################################################
def get_repos()
    loop do
        $client.org_repos($org, {:type => 'all'})
        rate_limit = $client.rate_limit
        if rate_limit.remaining > 0 then
            break
        end
        sleep($wait)
    end

    repos = []

    last_response = $client.last_response
    data = last_response.data
    data.each { |repo|
        repo = get_repo_metadata(repo)
        if !repo.empty? then
            repos << repo
        end
    }

    until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        data = last_response.data
        data.each { |repo|
            repo = get_repo_metadata(repo)
            if !repo.empty? then
                repos << repo
            end
        }
    end

    return repos
end


#########################################################################################
def get_repo_invitations(repo)
    loop do
        $client.repository_invitations(repo)
        rate_limit = $client.rate_limit
        if rate_limit.remaining > 0 then
            break
        end
        sleep($wait)
    end

    last_response = $client.last_response
    invitations = last_response.data

    until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        invitations << last_response.data
    end

    return invitations
end


#########################################################################################
def get_repo_collaborators(repo)
    loop do
        $client.collaborators(repo)
        rate_limit = $client.rate_limit
        if rate_limit.remaining > 0 then
            break
        end
        sleep($wait)
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
    begin
        $client.user(user)
    rescue
        puts "- Requested action for not existing user \"#{user}\" ❌"
    else
        if $client.org_member?($org, user) then
            puts "- Requested action for organization member \"#{user}\" ❌"
        else
            # "write" is the highest allowed permission we can handle
            # in order to make sure that malicious collaborators
            # won't be able to elevate themselves
            auth_ = auth
            if auth_.casecmp?("maintain") || auth_.casecmp?("admin")
                auth_ = "write"
            elsif !auth_.casecmp?("read") && !auth_.casecmp?("triage") && !auth_.casecmp?("write") then
                auth_ = "read"
            end
            print "- Inviting/updating collaborator \"#{user}\" with permission \"#{auth_}\""
            if !auth_.casecmp?(auth) && !auth.casecmp?("read") then
                print " (⚠ \"#{auth}\" is not allowed/available)"
            end
            print "\n"

            get_repo_invitations(repo).each { |invitation|
                if invitation.invitee.login.casecmp?(user) then
                    $client.update_repository_invitation(repo, invitation.id, permission: auth_)
                    return
                end
            }

            # remap permissions
            if auth_.casecmp?("read") then
                auth_ = "pull"
            elsif auth_.casecmp?("write") then
                auth_ = "push"
            end
            $client.add_collaborator(repo, user, permission: auth_)
        end
    end
end


#########################################################################################
# main

# retrieve groups information
groupsfiles = Dir["../groups/*.yml"]
groupsfiles << Dir["../groups/*.yaml"]

groups = {}
groupsfiles.each { |file|
    if !file.empty? then
        groups.merge!(YAML.load_file(file))
    end
}

# cycle over repos
get_repos().each { |repo|
    repo_name = repo.keys[0]
    repo_metadata = repo.values[0]
    
    puts "Processing \"#{repo_name}\"..."

    # clean up all pending invitations
    # so that we can revive those stale
    get_repo_invitations(repo_name).each { |invitation|
        puts "- Deleting invitee \"#{invitation.invitee.login}\""
        $client.delete_repository_invitation(repo_name, invitation.id)
    }

    # add collaborators
    repo_metadata.each { |user, props|
        type = props["type"]
        permission = props["permission"]
        if (type.casecmp?("user")) then
            add_repo_collaborator(repo_name, user, permission)
        elsif (type.casecmp?("group")) then
            if groups.key?(user) then
                puts "- Handling group \"#{user}\" 👥"
                groups[user].each { |subuser|
                    add_repo_collaborator(repo_name, subuser, permission)
                }
            else
                puts "- Unrecognized group \"#{user}\" ❌"
            end
        else
            puts "- Unrecognized type \"#{type}\" ❌"
        end
    }

    # remove collaborators no longer requested
    get_repo_collaborators(repo_name).each { |user|
        if !$client.org_member?($org, user) then
            if !repo_metadata.key?(user) && !groups.has_value?(user) then
                puts "- Removing collaborator \"#{user}\""
                $client.remove_collaborator(repo_name, user)
            end
        end
    }

    puts "...done with \"#{repo_name}\" ✔"
}
