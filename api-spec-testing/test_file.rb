# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require_relative 'test_file/action'
require_relative 'test_file/test'
require_relative 'test_file/task_group'

module Elasticsearch

  module RestAPIYAMLTests

    # Class representing a single test file, containing a setup, teardown, and multiple tests.
    #
    # @since 6.2.0
    class TestFile

      attr_reader :features_to_skip
      attr_reader :name

      # Initialize a single test file.
      #
      # @example Create a test file object.
      #   TestFile.new(file_name)
      #
      # @param [ String ] file_name The name of the test file.
      # @param [ Array<Symbol> ] skip_features The names of features to skip.
      #
      # @since 6.1.0
      def initialize(file_name, features_to_skip = [])
        @name = file_name
        documents = YAML.load_stream(File.new(file_name))
        @test_definitions = documents.reject { |doc| doc['setup'] || doc['teardown'] }
        @setup = documents.find { |doc| doc['setup'] }
        @teardown = documents.find { |doc| doc['teardown'] }
        @features_to_skip = REST_API_YAML_SKIP_FEATURES + features_to_skip
      end

      # Get a list of tests in the test file.
      #
      # @example Get the list of tests
      #   test_file.tests
      #
      # @return [ Array<Test> ] A list of Test objects.
      #
      # @since 6.2.0
      def tests
        @test_definitions.collect do |test_definition|
          Test.new(self, test_definition)
        end
      end

      # Run the setup tasks defined for a single test file.
      #
      # @example Run the setup tasks.
      #   test_file.setup(client)
      #
      # @param [ Elasticsearch::Client ] client The client to use to perform the setup tasks.
      #
      # @return [ self ]
      #
      # @since 6.2.0
      def setup(client)
        return unless @setup
        actions = @setup['setup'].select { |action| action['do'] }.map { |action| Action.new(action['do']) }
        actions.each do |action|
          action.execute(client)
        end
        self
      end

      # Run the teardown tasks defined for a single test file.
      #
      # @example Run the teardown tasks.
      #   test_file.teardown(client)
      #
      # @param [ Elasticsearch::Client ] client The client to use to perform the teardown tasks.
      #
      # @return [ self ]
      #
      # @since 6.2.0
      def teardown(client)
        return unless @teardown
        actions = @teardown['teardown'].select { |action| action['do'] }.map { |action| Action.new(action['do']) }
        actions.each { |action| action.execute(client) }
        self
      end

      class << self

        # Prepare Elasticsearch for a single test file.
        # This method deletes indices, roles, datafeeds, etc.
        #
        # @since 6.2.0
        def clear_data(client)
          clear_indices(client)
          clear_index_templates(client)
          clear_snapshots_and_repositories(client)
        end

        # Prepare Elasticsearch for a single test file.
        # This method deletes indices, roles, datafeeds, etc.
        #
        # @since 6.2.0
        def clear_data_xpack(client)
          clear_roles(client)
          clear_users(client)
          clear_privileges(client)
          clear_datafeeds(client)
          clear_ml_jobs(client)
          clear_rollup_jobs(client)
          clear_tasks(client)
          clear_machine_learning_indices(client)
          create_x_pack_rest_user(client)
          clear_data(client)
        end

        private

        def create_x_pack_rest_user(client)
          client.xpack.security.put_user(username: 'x_pack_rest_user',
                                         body: { password: 'x-pack-test-password', roles: ['superuser'] })
        end

        def clear_roles(client)
          client.xpack.security.get_role.each do |role, _|
            begin; client.xpack.security.delete_role(name: role); rescue; end
          end
        end

        def clear_users(client)
          client.xpack.security.get_user.each do |user, _|
            begin; client.xpack.security.delete_user(username: user); rescue; end
          end
        end

        def clear_privileges(client)
          client.xpack.security.get_privileges.each do |privilege, _|
            begin; client.xpack.security.delete_privileges(name: privilege); rescue; end
          end
        end

        def clear_datafeeds(client)
          client.xpack.ml.stop_datafeed(datafeed_id: '_all', force: true)
          client.xpack.ml.get_datafeeds['datafeeds'].each do |d|
            client.xpack.ml.delete_datafeed(datafeed_id: d['datafeed_id'])
          end
        end

        def clear_ml_jobs(client)
          client.xpack.ml.close_job(job_id: '_all', force: true)
          client.xpack.ml.get_jobs['jobs'].each do |d|
            client.xpack.ml.delete_job(job_id: d['job_id'])
          end
        end

        def clear_rollup_jobs(client)
          client.xpack.rollup.get_jobs(id: '_all')['jobs'].each do |d|
            client.xpack.rollup.stop_job(id: d['config']['id'])
            client.xpack.rollup.delete_job(id: d['config']['id'])
          end
        end

        def clear_tasks(client)
          tasks = client.tasks.get['nodes'].values.first['tasks'].values.select do |d|
            d['cancellable']
          end.map do |d|
            "#{d['node']}:#{d['id']}"
          end
          tasks.each { |t| client.tasks.cancel task_id: t }
        end

        def clear_machine_learning_indices(client)
          client.indices.delete(index: '.ml-*', ignore: 404)
        end

        def clear_index_templates(client)
          client.indices.delete_template(name: '*')
        end

        def clear_snapshots_and_repositories(client)
          client.snapshot.get_repository(repository: '_all').keys.each do |repository|
            client.snapshot.get(repository: repository, snapshot: '_all')['snapshots'].each do |s|
              client.snapshot.delete(repository: repository, snapshot: s['snapshot'])
            end
            client.snapshot.delete_repository(repository: repository)
          end
        end

        def clear_indices(client)
          indices = client.indices.get(index: '_all').keys.reject do |i|
            i.start_with?('.security') || i.start_with?('.watches')
          end
          indices.each do |index|
            client.indices.delete_alias(index: index, name: '*', ignore: 404)
            client.indices.delete(index: index, ignore: 404)
          end
          # See cat.aliases/10_basic.yml, test_index is not return in client.indices.get(index: '_all')
          client.indices.delete(index: 'test_index', ignore: 404)
          client.indices.delete(index: 'index1', ignore: 404)
          client.indices.delete(index: 'index_closed', ignore: 404)
          client.indices.delete(index: 'bar', ignore: 404)
          client.indices.delete(index: 'test_close_index', ignore: 404)
          client.indices.delete(index: 'test_index_3', ignore: 404)
          client.indices.delete(index: 'test_index_2', ignore: 404)
          client.indices.delete(index: 'test-xyy', ignore: 404)
        end
      end
    end
  end
end
