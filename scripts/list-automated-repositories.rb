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
def check_user(user, permission)
    begin
        $client.user(user)
    rescue
        puts "- \"#{user}\" does not exist ❌"
    else
        if $client.org_member?($org, user) then
            puts "- \"#{user}\" is also organization member ❌"
        else
            puts "- \"#{user}\" with permission \"#{permission}\""
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
    
    puts "Processing automated repository \"#{repo_name}\"..."

    # list collaborators
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
            end
        else
            puts "- Unrecognized type \"#{type}\" ❌"
        end
    }

    puts "...done with \"#{repo_name}\" ✔"
    puts ""
}
