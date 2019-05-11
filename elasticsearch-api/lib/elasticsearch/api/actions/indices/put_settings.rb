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

module Elasticsearch
  module API
    module Indices
      module Actions

        # Update the settings for one or multiple indices.
        #
        # @example Change the number of replicas for all indices
        #
        #     client.indices.put_settings body: { index: { number_of_replicas: 0 } }
        #
        #
        # @example Change the number of replicas for a specific index
        #
        #     client.indices.put_settings index: 'myindex', body: { index: { number_of_replicas: 0 } }
        #
        #
        # @example Disable "flush" for all indices
        #
        #     client.indices.put_settings body: { 'index.translog.disable_flush' => true }
        #
        # @example Allocate specific index on specific nodes
        #
        #     client.indices.put_settings index: 'my-big-index',
        #                                 body: { 'index.routing.allocation.require.tag' => 'bigbox' }
        #
        # @option arguments [List] :index A comma-separated list of index names; use `_all` or empty string to perform the operation on all indices
        # @option arguments [Hash] :body The index settings to be updated (*Required*)
        # @option arguments [Time] :master_timeout Specify timeout for connection to master
        # @option arguments [Time] :timeout Explicit operation timeout
        # @option arguments [Boolean] :preserve_existing Whether to update existing settings. If set to `true` existing settings on an index remain unchanged, the default is `false`
        # @option arguments [Boolean] :ignore_unavailable Whether specified concrete indices should be ignored when unavailable (missing or closed)
        # @option arguments [Boolean] :allow_no_indices Whether to ignore if a wildcard indices expression resolves into no concrete indices. (This includes `_all` string or when no indices have been specified)
        # @option arguments [String] :expand_wildcards Whether to expand wildcard expression to concrete indices that are open, closed or both. (options: open, closed, none, all)
        # @option arguments [Boolean] :flat_settings Return settings in flat format (default: false)
        #
        # @see https://www.elastic.co/guide/reference/api/admin-indices-update-settings/
        #
        def put_settings(arguments={})
          raise ArgumentError, "Required argument 'body' missing" unless arguments[:body]
          method = HTTP_PUT
          path   = Utils.__pathify Utils.__listify(arguments[:index]), '_settings'
          params = Utils.__validate_and_extract_params arguments, ParamsRegistry.get(__method__)
          body   = arguments[:body]

          perform_request(method, path, params, body).body
        end

        # Register this action with its valid params when the module is loaded.
        #
        # @since 6.1.1
        ParamsRegistry.register(:put_settings, [
            :master_timeout,
            :timeout,
            :preserve_existing,
            :ignore_unavailable,
            :allow_no_indices,
            :expand_wildcards,
            :flat_settings ].freeze)
      end
    end
  end
end
