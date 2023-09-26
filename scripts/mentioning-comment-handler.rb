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
$repo = ENV['OUTSIDE_COLLABORATORS_GITHUB_REPO']
$event_name = ENV['OUTSIDE_COLLABORATORS_GITHUB_EVENT_NAME']
$issue_number = ENV['OUTSIDE_COLLABORATORS_GITHUB_ISSUE_NUMBER']
$pr_number = ENV['OUTSIDE_COLLABORATORS_GITHUB_PR_NUMBER']
$comment_id = ENV['OUTSIDE_COLLABORATORS_GITHUB_COMMENT_ID']
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

# print request payload
puts "Received request with the following payload data:"
puts "- repository   = \"#{$repo}\""
puts "- event_name   = \"#{$event_name}\""
puts "- issue_number = \"#{$issue_number}\""
puts "- pr_number    = \"#{$pr_number}\""
puts "- comment_id   = \"#{$comment_id}\""

# retrieve information from files
groups = get_entries("../groups")
repos = get_entries("../repos")

# remove empty groups
groups.compact!

# retrieve metadata
repo_name = $repo.split('/')[-1]
if repos.key?(repo_name) then
    repo_metadata = repos[repo_name]
else
    puts "Repository \"#{$repo}\" is not automated ❌"
    exit 1
end

# retrieve message info
check_and_wait_until_reset
if $event_name.casecmp?("issues") then
    info = $client.issue($repo, $issue_number)
elsif $event_name.casecmp?("issue_comment") then
    info = $client.issue_comment($repo, $comment_id)
elsif $event_name.casecmp?("pull_request_target") ||
      $event_name.casecmp?("pull_request_review") then
    info = $client.pull_request($repo, $pr_number)
else
    puts "Unhandled event \"#{$event_name}\" ❌"
    exit 1
end

if info.nil? then
    puts "Wrong information received ❌"
    exit 1
end

body = info.body
author = info.user.login

if body.nil? then
    puts "Empty message detected 🤷🏻"
    exit 0
end

# cycle over repo's users
collaborators = ""
repo_metadata.each { |user, props|
    if (props["type"].casecmp?("group")) then
        tag = "!" + user
        if body.include? tag then
            # avoid self-notifying
            body = body.gsub(tag, user)
            if groups.key?(user) then
                puts "- Handling of notified group \"#{user}\" 👥"
                groups[user].each { |subuser|
                    # take the author out of the notification list
                    if !subuser.casecmp?(author) then
                        collaborators << "@" + subuser + " "
                    end
                }
            else
                puts "Unrecognized group \"#{user}\" ⚠"
            end
        end
    end
}

if !collaborators.empty? then
    # quote initial portion of the original message
    header_max_length = 500
    if body.length <= header_max_length then
        header = body
    else
        header = body.slice(0, header_max_length)
        header << "..."
    end
    quoted_header = (">" + header).gsub("\n","\n>")

    notification = quoted_header + "\n\n@" + author + " wanted to notify the following collaborators:\n\n" + collaborators
    if ($event_name.include? "issue") then
        n = $issue_number
    else
        n = $pr_number
    end
    puts "Posting notification 👋🏻"
    $client.add_comment($repo, n, notification)
end
