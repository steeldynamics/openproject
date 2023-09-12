# frozen_string_literal: true

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
#
module Storages::Admin
  class OpPrimerListComponent < Primer::Beta::BorderBox
    attr_reader :storages

    def initialize(storages:, padding: :default, scheme: :default, **system_arguments)
      @storages = storages
      super(padding:, scheme:, **system_arguments)
    end

    def header
      render(Primer::Beta::BorderBox::Header.new) do |header_|
        header_.with_title(tag: :h2) do
          header_title
        end
      end
    end

    def header_title
      helpers.pluralize(storages.size, I18n.t("storages.label_storage"))
    end

    def render_collection
      render(::Storages::Admin::OpPrimerListItemComponent.with_collection(@storages))
    end

    private

    def before_render
      # FIXME: Add aria-lable for list arguments
      # See: https://github.com/primer/view_components/blob/main/app/components/primer/beta/border_box.rb#L94
    end
  end
end
