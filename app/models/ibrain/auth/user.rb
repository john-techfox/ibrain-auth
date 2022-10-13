# frozen_string_literal: true

module Ibrain
  module Auth
    class User < Ibrain::Base
      attr_accessor :jwt_token

      include Devise::JWT::RevocationStrategies::JTIMatcher

      self.table_name = Ibrain::Auth::Config.user_table_name

      devise :database_authenticatable, :registerable, :confirmable,
             :recoverable, :validatable, :timeoutable,
             :jwt_authenticatable, jwt_revocation_strategy: self

      def jwt_payload
        # for hasura
        hasura_keys = {
            'https://hasura.io/jwt/claims': {
            'x-hasura-allowed-roles': Ibrain.user_class.roles.keys,
            'x-hasura-default-role': role,
            'x-hasura-user-id': id.to_s
          }
        }

        super.merge({ 'role' => role }, hasura_keys)
      end

      class << self
        def ibrain_find(params, available_columns)
          matched_value = params[:username] || params[:email]

          if matched_value.present?
            query = available_columns.map do |column_name|
              <<~RUBY
                #{column_name} = '#{matched_value}'
              RUBY
            end.join(' OR ')

            where(query).first
          end
        end

        def social_find_or_initialize(params)
          user = find_by(provider: params[:provider], uid: params[:uid])
          return user if user.present?

          create!(params)
        end
      end
    end
  end
end
