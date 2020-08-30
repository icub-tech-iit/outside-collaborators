#!/usr/bin/env ruby

# Copyright: (C) 2020 iCub Facility - Istituto Italiano di Tecnologia
# Authors: Ugo Pattacini <ugo.pattacini@iit.it>
# CopyPolicy: Released under the terms of the GNU GPL v3.0.
#
# The env variable GITHUB_TOKEN_VVV_SCHOOL shall contain a valid GitHub token
# (refer to instructions to find out more)

require 'octokit'

if ARGV.length < 1 then
  puts "Usage: $0 <organization>/<team>"
  exit 1
end
  
org_team=ARGV[0].split('/')
org=org_team[0]
team=org_team[1]
  
if org.to_s.empty? or team.to_s.empty? then
  puts "Invalid input <organization>/<team>"
  exit 1
end

Signal.trap("INT") {
  exit 2
}

Signal.trap("TERM") {
  exit 2
}

client = Octokit::Client.new :access_token => ENV['GITHUB_TOKEN_VVV_SCHOOL']
loop do
  client.org_teams(org)
  rate_limit = client.rate_limit
  if rate_limit.remaining > 0 then
    break
  end
  sleep(60)
end

last_response = client.last_response
data = last_response.data

team_id = -1
data.each { |x|
if x.name == team then
  team_id = x.id
end
}

if team_id < 0 then
  until last_response.rels[:next].nil?
    last_response = last_response.rels[:next].get
    data = last_response.data
    data.each { |x|
    if x.name == team then
      team_id = x.id
      break
    end
    }
  end
end

if team_id >= 0 then
  loop do
    client.team_members(team_id)
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
end

