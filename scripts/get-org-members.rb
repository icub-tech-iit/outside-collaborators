#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>

require 'octokit'

$org = ENV['OUTSIDE_COLLABORATORS_GITHUB_ORG']
$token = ENV['OUTSIDE_COLLABORATORS_GITHUB_TOKEN']

Signal.trap("INT") {
  exit 2
}

Signal.trap("TERM") {
  exit 2
}

client = Octokit::Client.new :access_token => $token
loop do
  client.org_members($org)
  rate_limit = client.rate_limit
  if rate_limit.remaining > 0 then
    break
  end
  sleep(60)
end

last_response = client.last_response
data = last_response.data
data.each { |x| puts "#{x.login}" }

until last_response.rels[:next].nil?
  last_response = last_response.rels[:next].get
  data = last_response.data
  data.each { |x| puts "#{x.login}" }
end
