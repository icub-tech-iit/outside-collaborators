#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>

require 'octokit'

$org = ENV['OUTSIDE_COLLABORATORS_GITHUB_ORG']
$token = ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']
$repo = ARGV[0]
$repofull = $org + '/' + $repo

Signal.trap("INT") {
  exit 2
}

Signal.trap("TERM") {
  exit 2
}

def process(client, invitation)
  client.delete_repository_invitation($repofull, invitation.id)
end

client = Octokit::Client.new :access_token => $token
loop do
  client.repository_invitations($repofull)
  rate_limit = client.rate_limit
  if rate_limit.remaining > 0 then
    break
  end
  sleep(60)
end

last_response = client.last_response
data = last_response.data
data.each { |invitation| process(client, invitation) }

until last_response.rels[:next].nil?
  last_response = last_response.rels[:next].get
  data = last_response.data
  data.each { |invitation| process(client, invitation) }
end
