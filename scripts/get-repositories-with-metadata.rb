#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Tech Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>
# CopyPolicy: Released under the terms of the GNU GPL v3.0.
#
# The env variable GITHUB_TOKEN_VVV_SCHOOL shall contain a valid GitHub token
# (refer to instructions to find out more)

require 'octokit'

org = ENV['GITHUB_ORG_OUTSIDE_COLLABORATORS']
token = ENV['GITHUB_TOKEN_OUTSIDE_COLLABORATORS']
metadata_file = '.outside-collaborators.yaml'

Signal.trap("INT") {
  exit 2
}

Signal.trap("TERM") {
  exit 2
}

def process(client, repo)
  begin
    metadata = client.contents(repo.full_name, :path => metadata_file)
  rescue
  else
    puts "#{repo.name}"
  end
end

client = Octokit::Client.new :access_token => token
loop do
  client.org_repos(org, {:type => 'all'})
  rate_limit = client.rate_limit
  if rate_limit.remaining > 0 then
    break
  end
  sleep(60)
end

last_response = client.last_response
data = last_response.data
data.each { |repo| process(client, repo) }

until last_response.rels[:next].nil?
  last_response = last_response.rels[:next].get
  data = last_response.data
  data.each { |repo| process(client, repo) }
end
