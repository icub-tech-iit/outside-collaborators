require_relative '../scripts/helpers'
require 'minitest/autorun'
 
$client = Minitest::Mock.new
def $client.rate_limit
    rate_limit = Minitest::Mock.new
    def rate_limit.remaining; return 100; end
    return rate_limit
end

def $client.repository_invitations(repo); return true; end

$response = Minitest::Mock.new
def $client.last_response
  def $response.rels; return {:next => nil}; end
  return $response
end

class TestHelpers < Minitest::Test
  def test_empty_get_repo_invitations
    $response.expect :data, []
    assert_equal(0, get_repo_invitations(Minitest::Mock.new).length)
  end
  
  def test_single_get_repo_invitations
    invite = Minitest::Mock.new
    def invite.expired; return false; end
    def invite.id; return nil; end
    def invite.permissions; return nil; end 
    def invite.invitee
      invitee = Minitest::Mock.new
      def invitee.login; return nil; end
      return invitee
    end

    $response.expect :data, [invite]
    assert_equal(1, get_repo_invitations(Minitest::Mock.new).length)
  end
  
  def test_single_with_expired_get_repo_invitations
    invite = Minitest::Mock.new
    def invite.expired; return false; end
    def invite.id; return nil; end
    def invite.permissions; return nil; end 
    def invite.invitee
      invitee = Minitest::Mock.new
      def invitee.login; return nil; end
      return invitee
    end

    invite2 = Minitest::Mock.new
    def invite2.expired; return true; end

    $response.expect :data, [invite, invite2]
    assert_equal(1, get_repo_invitations(Minitest::Mock.new).length)
  end
end
