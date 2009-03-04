# encoding: utf-8
#--
#   Copyright (C) 2008-2009 Marius Mathiesen <marius.mathiesen@gmail.com>
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
class Message < ActiveRecord::Base
  belongs_to :notifiable, :polymorphic => true
  belongs_to :sender, :class_name => "User", :foreign_key => :sender_id
  belongs_to :recipient, :class_name => "User", :foreign_key => :recipient_id
  belongs_to :in_reply_to, :class_name => 'Message', :foreign_key => :in_reply_to_id
  
  validates_presence_of :subject, :body

  include AASM
  aasm_initial_state :unread
  aasm_state :unread
  aasm_state :read
  
  aasm_event :read do 
    transitions :from => :unread, :to => :read
  end
  
  def build_reply(options={})
    reply_options = {:sender => recipient, :recipient => sender, :subject => "Re: #{subject}"}
    reply = Message.new(reply_options.merge(options))
    reply.in_reply_to = self
    return reply
  end
end