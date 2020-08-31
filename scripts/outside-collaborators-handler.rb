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
$repos = []
$repo_metadata = []
$groups = {}


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
        metadata = $client.contents(repo.full_name, :path => $metadata_filename)
    rescue
    else
        $repos << repo.full_name
        $repo_metadata << YAML.load(Base64.decode64(metadata.content))
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

    last_response = $client.last_response
    data = last_response.data
    data.each { |repo|
        get_repo_metadata(repo)
    }

    until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        data = last_response.data
        data.each { |repo|
            get_repo_metadata(repo)
        }
    end
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
            # "write" is the highest permission we can handle here
            # to make sure that malicious collaborators w/ "write"
            # access won't be able to elevate themselves
            auth_ = auth
            if auth_.casecmp?("maintain") || auth_.casecmp?("admin")
                auth_ = "write"
            end
            if !auth_.casecmp?("read") && !auth_.casecmp?("triage") &&
            !auth_.casecmp?("write") && !auth_.casecmp?("maintain") &&
            !auth_.casecmp?("admin") then
                auth_ = "read"
            end
            print "- Inviting/updating collaborator \"#{user}\" with permission \"#{auth_}\""
            if auth_ <=> auth then
                print " (⚠ \"#{auth}\" is not available/allowed)"
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
groupsfiles = Dir.entries("../groups/*.yml")
groupsfiles.each { |file|
    $groups.merge!(YAML.load(file))
}

i = 0
get_repos()
$repos.each { |repo|
    puts "Processing \"#{repo}\"..."

    # clean up all pending invitations
    # so that we can revive those stale
    get_repo_invitations(repo).each { |invitation|
        puts "- Deleting invitation to collaborator \"#{invitation.invitee.login}\""
        $client.delete_repository_invitation(repo, invitation.id)
    }

    # add collaborators
    $repo_metadata[i].each { |user, props|
        type = props["type"]
        permission = props["permission"]
        if (type.casecmp?("user")) then
            add_repo_collaborator(repo, user, permission)
        elsif (type.casecmp?("group")) then
            if $groups.key?(user) then
                puts "- Handling group \"#{user}\""
                $groups[user].each { |subuser|
                    add_repo_collaborator(repo, subuser, permission)
                }
            else
                puts "- Unrecognized group \"#{user}\" ❌"
            end
        else
            puts "- Unrecognized type \"#{type}\" ❌"
        end
    }

    # remove collaborators no longer requested
    get_repo_collaborators(repo).each { |user|
        if !$client.org_member?($org, user) then
            if !$repo_metadata[i].key?(user) && !$groups.has_value?(user) then
                puts "- Removing collaborator \"#{user}\""
                $client.remove_collaborator(repo, user)
            end
        end
    }

    puts "...done with \"#{repo}\" ✔"
    i = i + 1
}
