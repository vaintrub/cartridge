#!/usr/bin/env tarantool

require('strict').on()
_G.is_initialized = function() return false end

local log = require('log')
local cluster = require('cluster')

package.preload['mymodule'] = function()
    local state = nil
    local master = nil
    local service_registry = require('cluster.service-registry')
    local httpd = service_registry.get('httpd')

    if httpd ~= nil then
        httpd:route(
            {
                method = 'GET',
                path = '/custom-get',
                public = true,
            },
            function(req)
                return {
                    status = 200,
                    body = 'GET OK',
                }
            end
        )

        httpd:route(
            {
                method = 'POST',
                path = '/custom-post',
                public = true,
            },
            function(req)
                return {
                    status = 200,
                    body = 'POST OK',
                }
            end
        )
    end

    return {
        role_name = 'myrole',
        get_state = function() return state end,
        is_master = function() return master end,
        init = function(opts)
            state = 'initialized'
            assert(opts.is_master ~= nil)
        end,
        apply_config = function(_, opts)
            master = opts.is_master
        end,
        stop = function()
            state = 'stopped'
        end
    }
end

local ok, err = cluster.cfg({
    alias = os.getenv('ALIAS'),
    workdir = os.getenv('WORKDIR'),
    advertise_uri = os.getenv('ADVERTISE_URI') or 'localhost:3301',
    cluster_cookie = os.getenv('CLUSTER_COOKIE'),
    bucket_count = 10000,
    http_port = os.getenv('HTTP_PORT') or 8081,
    roles = {
        'mymodule'
    },
})

if not ok then
    log.error('%s', err)
    os.exit(1)
end

_G.is_initialized = cluster.is_healthy

function get_uuid()
    -- this function is used in pytest
    -- to check vshard routing
    return box.info().uuid
end
