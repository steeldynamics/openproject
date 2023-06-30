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

class MeetingsController < ApplicationController
  around_action :set_time_zone
  before_action :find_optional_project, only: %i[index index_in_wp_tab new create]
  before_action :build_meeting, only: %i[new create]
  before_action :find_meeting, except: %i[index index_in_wp_tab new create]
  before_action :convert_params, only: %i[create update]
  before_action :authorize, except: [:index, :index_in_wp_tab]
  before_action :authorize_global, only: [:index, :index_in_wp_tab]

  helper :watchers
  helper :meeting_contents
  include WatchersHelper
  include PaginationHelper
  include SortHelper

  menu_item :new_meeting, only: %i[new create]

  def index
    @meetings = @project ? @project.meetings : global_upcoming_meetings
  end

  def index_in_wp_tab
    @active_work_package = WorkPackage.find(params[:work_package_id]) unless params[:work_package_id].blank?
    @upcoming_meetings = @project.meetings.from_today.limit(10).reorder('start_time ASC')
    @past_meetings = @project.meetings.joins(:agenda_items)
      .where(['meetings.start_time < ?', Time.now.utc]).order('start_time DESC')
      .where('meeting_agenda_items.work_package_id = ?', @active_work_package.id)
      .distinct

    @discussed_agenda_items = @active_work_package.meeting_agenda_items.where.not(output: "")
    @open_agenda_items = @active_work_package.meeting_agenda_items.where(output: nil).where.not(input: nil)

    render layout: false
  end

  def show
    params[:tab] ||= 'minutes' if @meeting.agenda.present? && @meeting.agenda.locked?
  end

  def show_in_wp_tab
    @active_work_package = WorkPackage.find(params[:work_package_id]) unless params[:work_package_id].blank?
    params[:tab] ||= 'minutes' if @meeting.agenda.present? && @meeting.agenda.locked?
    render layout: false
  end

  def create
    @meeting.participants.clear # Start with a clean set of participants
    @meeting.participants_attributes = @converted_params.delete(:participants_attributes)
    @meeting.attributes = @converted_params
    if params[:copied_from_meeting_id].present? && params[:copied_meeting_agenda_text].present?
      @meeting.agenda = MeetingAgenda.new(
        text: params[:copied_meeting_agenda_text],
        journal_notes: I18n.t('meeting.copied', id: params[:copied_from_meeting_id])
      )
      @meeting.agenda.author = User.current
    end
    if @meeting.save
      text = I18n.t(:notice_successful_create)
      if User.current.time_zone.nil?
        link = I18n.t(:notice_timezone_missing, zone: Time.zone)
        text += " #{view_context.link_to(link, { controller: '/my', action: :account }, class: 'link_to_profile')}"
      end
      flash[:notice] = text.html_safe

      redirect_to action: 'show', id: @meeting
    else
      render template: 'meetings/new', project_id: @project
    end
  end

  def new; end

  current_menu_item :new do
    :meetings
  end

  def copy
    params[:copied_from_meeting_id] = @meeting.id
    params[:copied_meeting_agenda_text] = @meeting.agenda.text if @meeting.agenda.present?
    @meeting = @meeting.copy(author: User.current)
    render action: 'new', project_id: @project
  end

  def destroy
    @meeting.destroy
    flash[:notice] = I18n.t(:notice_successful_delete)
    redirect_to action: 'index', project_id: @project
  end

  def edit; end

  def update
    @meeting.participants_attributes = @converted_params.delete(:participants_attributes)
    @meeting.attributes = @converted_params
    if @meeting.save
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to action: 'show', id: @meeting
    else
      render action: 'edit'
    end
  end

  private

  def set_time_zone(&)
    zone = User.current.time_zone
    if zone.nil?
      localzone = Time.current.utc_offset
      localzone -= 3600 if Time.current.dst?
      zone = ::ActiveSupport::TimeZone[localzone]
    end

    Time.use_zone(zone, &)
  end

  def build_meeting
    @meeting = Meeting.new
    @meeting.project = @project
    @meeting.author = User.current
  end

  def find_optional_project
    return true unless params[:project_id]

    @project = Project.find(params[:project_id])
    authorize
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def global_upcoming_meetings
    projects = Project.allowed_to(User.current, :view_meetings)

    Meeting.where(project: projects).from_today
  end

  def find_meeting
    @meeting = Meeting
               .includes([:project, :author, { participants: :user }, :agenda, :minutes])
               .find(params[:id])
    @project = @meeting.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def convert_params
    # We do some preprocessing of `meeting_params` that we will store in this
    # instance variable.
    @converted_params = meeting_params.to_h

    @converted_params[:duration] = @converted_params[:duration].to_hours
    # Force defaults on participants
    @converted_params[:participants_attributes] ||= {}
    @converted_params[:participants_attributes].each { |p| p.reverse_merge! attended: false, invited: false }
  end

  def meeting_params
    params.require(:meeting).permit(:title, :location, :start_time, :duration, :start_date, :start_time_hour,
                                    participants_attributes: %i[email name invited attended user user_id meeting id])
  end
end
