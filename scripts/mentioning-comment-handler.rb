#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>


#########################################################################################
# deps
require 'octokit'
require 'yaml'

#########################################################################################
# global vars
$repo = ENV['OUTSIDE_COLLABORATORS_GITHUB_REPO']
$event_name = ENV['OUTSIDE_COLLABORATORS_GITHUB_EVENT_NAME']
$issue_number = ENV['OUTSIDE_COLLABORATORS_GITHUB_ISSUE_NUMBER']
$pr_number = ENV['OUTSIDE_COLLABORATORS_GITHUB_PR_NUMBER']
$comment_id = ENV['OUTSIDE_COLLABORATORS_GITHUB_COMMENT_ID']
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
# main

# print request payload
puts "Received request with the following payload data:"
puts "- repository   = \"#{$repo}\""
puts "- event_name   = \"#{$event_name}\""
puts "- issue_number = \"#{$issue_number}\""
puts "- pr_number    = \"#{$pr_number}\""
puts "- comment_id   = \"#{$comment_id}\""

# retrieve message info
begin
    repo_metadata = $client.contents($repo, :path => $metadata_filename)
rescue
    puts "Repository \"#{$repo}\" does not contain metadata ❌"
    exit 1
else
    repo_metadata=YAML.load(Base64.decode64(repo_metadata.content))
end

if $event_name.casecmp?("issues") then
    info = $client.issue($repo, $issue_number)
elsif $event_name.casecmp?("issue_comment") then
    info = $client.issue_comment($repo, $comment_id)
elsif $event_name.casecmp?("pull_request_target") ||
      $event_name.casecmp?("pull_request_review") then
    info = $client.pull_request($repo, $pr_number)
elsif $event_name.casecmp?("pull_request_review_comment") then
    info = $client.pull_request_comment($repo, $comment_id)
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

# retrieve groups information
groupsfiles = Dir["../groups/*.yml"]
groupsfiles << Dir["../groups/*.yaml"]

groups = {}
groupsfiles.each { |file|
    if !file.empty? then
        groups.merge!(YAML.load_file(file))
    end
}

# cycle over repo's users
collaborators = ""
repo_metadata.each { |user, props|
    if (props["type"].casecmp?("group")) then
        if (body.include? ("$" + user)) || (body.include? ("${" + user + "}")) then
            if groups.key?(user) then
                puts "- Handling of notified group \"#{user}\" 👥"
                groups[user].each { |subuser|
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
    notification = "@" + author + " wanted to notify the following collaborators:\n\n" + collaborators
    puts "Posting the following comment:\n#{notification}"
    if ($event_name.include? "issue") then
        $client.add_comment($repo, $issue_number, notification)
    elsif $event_name.casecmp?("pull_request_target") ||
          $event_name.casecmp?("pull_request_review") then
        $client.add_comment($repo, $pr_number, notification)
    else
        $client.create_pull_request_comment_reply($repo, info.pull_request_review_id, notification, $comment_id)
    end
end
