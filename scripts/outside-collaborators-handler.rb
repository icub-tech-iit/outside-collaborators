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
$yaml_repo_metadata = []


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
        $yaml_repo_metadata << YAML.load(Base64.decode64(metadata.content))
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
def delete_repo_invitations(repo)
    loop do
        $client.repository_invitations(repo)
        rate_limit = $client.rate_limit
        if rate_limit.remaining > 0 then
            break
        end
        sleep($wait)
    end

    last_response = $client.last_response
    data = last_response.data
    data.each { |invitation|
        puts "- Deleting invitation to collaborator \"#{invitation.invitee.login}\""
        $client.delete_repository_invitation(repo, invitation.id)
    }

    until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        data = last_response.data
        data.each { |invitation|
            puts "- Deleting invitation to collaborator \"#{invitation.invitee.login}\""
            $client.delete_repository_invitation(repo, invitation.id)
        }
    end
end


#########################################################################################
def add_repo_collaborator(repo, user, auth)
    # "write" is the highest permission we can handle here
    # to be safe against malicious collaborators w/ "write"
    # permission who can elevate themselves otherwise
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
        print " (\"#{auth}\" is not available/allowed)"
    end
    print "\n"
    
    # remap permissions
    if auth_.casecmp?("read") then
        auth_ = "pull"
    elsif auth_.casecmp?("write") then
        auth_ = "push"
    end

    $client.add_collaborator(repo, user, permission: auth_)
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
# main
get_repos()
i = 0
$repos.each { |repo|
    puts "Processing \"#{repo}\"..."

    # adding a collaborator again will trigger a new invitation
    # so that stale invitations get revived, plus we clean up
    # invitations that are no longer requested
    delete_repo_invitations(repo)

    # add collaborators
    $yaml_repo_metadata[i].each { |user, props|
        # cycle over users, not groups
        if (props["type"].casecmp?("user")) then
            begin
                # check that the user is actually existing
                $client.user(user)
            rescue
            else
                if !$client.org_member?($org, user) then
                    add_repo_collaborator(repo, user, props["permission"])
                end
            end
        end
    }

    # remove collaborators no longer requested
    get_repo_collaborators(repo).each { |user|
        if !$client.org_member?($org, user) then
            if !$yaml_repo_metadata[i].key?(user) then
                puts "- Removing collaborator \"#{user}\""
                $client.remove_collaborator(repo, user)
            end
        end
    }

    puts "...done with \"#{repo}\" ✔"
    i = i + 1
}
