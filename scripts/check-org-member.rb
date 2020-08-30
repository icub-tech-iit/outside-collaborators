#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>

require 'octokit'

$org = ENV['OUTSIDE_COLLABORATORS_GITHUB_ORG']
$token = ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']
$user = ARGV[0]

client = Octokit::Client.new :access_token => $token
print "checking membership of #{$user} ... "
if client.org_member?($org, $user)
  print "✔\n"
  exit 0
else
  print "❌\n"
  exit 1
end
