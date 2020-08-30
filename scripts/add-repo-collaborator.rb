#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>

require 'octokit'

$org = ENV['OUTSIDE_COLLABORATORS_GITHUB_ORG']
$token = ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']
$repo = ARGV[0]
$user = ARGV[1]
$permission = ARGV[2]
$repofull = $org + '/' + $repo

if !$permission.casecmp?("pull") && !$permission.casecmp?("triage") &&
   !$permission.casecmp?("push") && !$permission.casecmp?("maintain") &&
   !$permission.casecmp?("admin")
  $permission = "pull"
end

client = Octokit::Client.new :access_token => $token
client.add_collaborator($repofull, $user, permission: $permission)
