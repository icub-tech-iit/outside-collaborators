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
# main

# retrieve information from files
groups = get_entries("../groups")
repos = get_entries("../repos")

# retrieve input repos 
repos_input = ENV['OUTSIDE_COLLABORATORS_REPOS_DELETE_INVITATIONS'].split(/\s*,\s*/)
puts "📃 List of automated repositories to process: #{repos_input}"

# cycle over repos
repos.each { |repo_name, repo_metadata|
    repo_full_name = $org + "/" + repo_name
    puts "Processing automated repository \"#{repo_full_name}\"..."

    check_and_wait_until_reset
    if $client.repository?(repo_full_name) then
        # check if we're required to deal with this repo
        if repos_input.include?('*') || repos_input.include?(repo_name) then
            # delete invitations
            get_repo_invitations(repo_full_name).each { |invitation|
                invitee = invitation["invitee"]
                check_and_wait_until_reset
                if !$client.org_member?($org, invitee) then
                    puts "- Removing invitee \"#{invitee}\""
                    check_and_wait_until_reset
                    $client.delete_repository_invitation(repo_full_name, invitation["id"])
                end
            }

            puts "...done with \"#{repo_full_name}\" ✔"
        else
            puts "Repository \"#{repo_full_name}\" is not in the list ➖"
        end
    else
        puts "Repository \"#{repo_full_name}\" does not exist ❌"
    end
    puts ""
}
