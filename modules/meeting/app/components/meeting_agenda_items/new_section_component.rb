#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module MeetingAgendaItems
  class NewSectionComponent < Base::OpTurbo::Component
    def initialize(meeting:, meeting_agenda_item: nil, state: :initial, active_work_package: nil, **kwargs)
      @meeting = meeting
      @meeting_agenda_item = meeting_agenda_item || MeetingAgendaItem.new(meeting: meeting, work_package: active_work_package)
      @state = state
      @active_work_package = active_work_package
    end

    def call
      component_wrapper do
        case @state
        when :initial
          render(MeetingAgendaItems::NewSectionComponent::ButtonComponent.new(**child_component_params))
        when :form
          render(MeetingAgendaItems::NewSectionComponent::FormComponent.new(**child_component_params))
        end
      end
    end

    private

    def child_component_params
      {
        meeting: @meeting,
        active_work_package: @active_work_package,
        meeting_agenda_item: @meeting_agenda_item
      }
    end
  end
end
