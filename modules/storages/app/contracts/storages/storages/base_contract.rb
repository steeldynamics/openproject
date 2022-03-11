#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
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

require 'net/http'
require 'uri'

# Purpose: common functionalities shared by CreateContract and UpdateContract
# UpdateService by default checks if UpdateContract exists
# and uses the contract to validate the model under consideration
# (normally it's a model).
module Storages::Storages
  class BaseContract < ::ModelContract
    MINIMAL_NEXTCLOUD_VERSION = 23

    include ::Storages::Storages::Concerns::ManageStoragesGuarded
    include ActiveModel::Validations

    attribute :name
    validates :name, length: { minimum: 1, maximum: 255 }, allow_nil: false

    attribute :provider_type
    validates :provider_type, inclusion: { in: ->(*) { Storages::Storage::PROVIDER_TYPES } }, allow_nil: false

    attribute :creator, writable: false do
      validate_creator_is_user
    end

    attribute :host
    validates :host, url: true

    # Check that a host actually is a storage server.
    # But only do so if the validations above for URL were successful.
    validate :validate_host_reachable, unless: -> { errors.include?(:host) }

    def validate_creator_is_user
      unless creator == user
        errors.add(:creator, :invalid)
      end
    end

    def validate_host_reachable
      return unless model.host_changed?

      response = request_capabilities

      unless response.is_a? Net::HTTPSuccess
        errors.add(:host, :invalid)
        return
      end

      unless major_version_sufficient?(response)
        errors.add(:host, :invalid)
      end
    end

    def major_version_sufficient?(response)
      return false unless response.body

      version = JSON.parse(response.body).dig('ocs', 'data', 'version', 'major')
      return false if version.nil?
      return false if version < MINIMAL_NEXTCLOUD_VERSION

      true
    end

    private

    def request_capabilities
      uri = URI.parse(File.join(host, '/ocs/v2.php/cloud/capabilities'))
      request = Net::HTTP::Get.new(uri)
      request["Ocs-Apirequest"] = "true"
      request["Accept"] = "application/json"

      req_options = {
        max_retries: 0,
        open_timeout: 5, # seconds
        read_timeout: 3, # seconds
        use_ssl: uri.scheme == "https"
      }

      begin
        Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
      rescue StandardError
        :unreachable
      end
    end
  end
end
