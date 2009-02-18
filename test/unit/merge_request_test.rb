# encoding: utf-8
#--
#   Copyright (C) 2008-2009 Johan Sørensen <johan@johansorensen.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++


require File.dirname(__FILE__) + '/../test_helper'

class MergeRequestTest < ActiveSupport::TestCase

  def setup
    @merge_request = merge_requests(:moes_to_johans)
    commits = %w(9dbb89110fc45362fc4dc3f60d960381 6823e6622e1da9751c87380ff01a1db1 526fa6c0b3182116d8ca2dc80dedeafb 286e8afb9576366a2a43b12b94738f07).collect do |sha|
      m = mock
      m.stubs(:id).returns(sha)
      m
    end
    @merge_request.stubs(:commits_for_selection).returns(commits)
  end
  
  should_validate_presence_of :user, :source_repository, :target_repository, 
                              :ending_commit
  
  should "emails the owner of the target_repository on create" do
    Mailer.deliveries = []
    mr = @merge_request.clone
    mr.save
    assert !Mailer.deliveries.empty?, 'empty? should be false'
  end
  
  should "has a merged? status" do
    @merge_request.status = MergeRequest::STATUS_MERGED
    assert @merge_request.merged?, '@merge_request.merged? should be true'
  end
  
  should "has a rejected? status" do
    @merge_request.status = MergeRequest::STATUS_REJECTED
    assert @merge_request.rejected?, '@merge_request.rejected? should be true'
  end
  
  should "has a open? status" do
    @merge_request.status = MergeRequest::STATUS_OPEN
    assert @merge_request.open?, '@merge_request.open? should be true'
  end
  
  should "has a statuses class method" do
    assert_equal MergeRequest::STATUS_OPEN, MergeRequest.statuses["Open"]
    assert_equal MergeRequest::STATUS_MERGED, MergeRequest.statuses["Merged"]
    assert_equal MergeRequest::STATUS_REJECTED, MergeRequest.statuses["Rejected"]
  end
  
  should "has a status_string" do
    MergeRequest.statuses.each do |k,v|
      @merge_request.status = v
      assert_equal k.downcase, @merge_request.status_string
    end
  end
  
  should "knows who can resolve itself" do
    assert @merge_request.resolvable_by?(users(:johan)), '@merge_request.resolvable_by?(users(:johan)) should be true'
    @merge_request.target_repository.owner = groups(:team_thunderbird)
    assert @merge_request.resolvable_by?(users(:mike)), '@merge_request.resolvable_by?(users(:mike)) should be true'
    assert !@merge_request.resolvable_by?(users(:moe)), '@merge_request.resolvable_by?(users(:moe)) should be false'
  end
  
  should "counts open merge_requests" do
    mr = @merge_request.clone
    mr.status = MergeRequest::STATUS_REJECTED
    mr.save
    assert_equal 1, MergeRequest.count_open
  end
  
  should "it defaults to master for the source_branch" do
    mr = MergeRequest.new
    assert_equal "master", mr.source_branch
    mr.source_branch = "foo"
    assert_equal "foo", mr.source_branch
  end
  
  should "it defaults to master for the target_branch" do
    mr = MergeRequest.new
    assert_equal "master", mr.target_branch
    mr.target_branch = "foo"
    assert_equal "foo", mr.target_branch
  end
  
  should "has a source_name" do
    @merge_request.source_branch = "foo"
    assert_equal "#{@merge_request.source_repository.name}:foo", @merge_request.source_name
  end
  
  should "has a target_name" do
    @merge_request.target_branch = "foo"
    assert_equal "#{@merge_request.target_repository.name}:foo", @merge_request.target_name
  end
  
  should "have an empty set of target branches, if the target_repository is nil" do
    @merge_request.target_repository = nil
    assert_equal [], @merge_request.target_branches_for_selection
  end
  
  should "have a set of target branches" do
    repo = repositories(:johans)
    @merge_request.target_repository = repo
    grit = Grit::Repo.new(grit_test_repo("dot_git"), :is_bare => true)
    repo.stubs(:git).returns(grit)
    assert_equal grit.heads, @merge_request.target_branches_for_selection
  end
  
  context "with specific starting and ending commits" do
    setup do
      @merge_request.ending_commit = '6823e6622e1da9751c87380ff01a1db1'
    end
    
    should "not blow up if there's no target repository" do
      mr = MergeRequest.new
      assert_nothing_raised do
        assert_equal [], mr.commits_for_selection
      end
    end
    
    should " suggest relevant commits to be merged" do
      assert_equal(4, @merge_request.commits_for_selection.size)
    end
    
    should " know that it applies to specific commits" do
      assert_equal(2, @merge_request.commits_to_be_merged.size)
      assert_equal(%w(9dbb89110fc45362fc4dc3f60d960381 6823e6622e1da9751c87380ff01a1db1), @merge_request.commits_to_be_merged.collect(&:id))
    end
    
    should " return the full set of commits if ending_commit or starting_commit don't exist" do
      @merge_request.ending_commit = '526fa6c0b3182116d8ca2dc80dedeafb'
      assert_equal(3, @merge_request.commits_to_be_merged.size)
    end
  end
end