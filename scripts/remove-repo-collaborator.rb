#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>

require 'octokit'

$org = ENV['OUTSIDE_COLLABORATORS_GITHUB_ORG']
$token = ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']
$repo = ARGV[0]
$user = ARGV[1]
$repofull = $org + '/' + $repo

client = Octokit::Client.new :access_token => $token
client.remove_collaborator($repofull, $user)
