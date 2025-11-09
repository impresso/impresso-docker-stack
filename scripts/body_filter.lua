-- Get the current state
local is_json = ngx.ctx.buffered_body ~= nil;
local body_chunk = ngx.arg[1];
local is_eof = ngx.arg[2];

-- Only proceed if we have identified it as a JSON response
if is_json then
    -- Append the current chunk to the buffer
    ngx.ctx.buffered_body = ngx.ctx.buffered_body .. body_chunk;

    -- Clear the current chunk (important to prevent double-output)
    ngx.arg[1] = "";

    -- Check if this is the last chunk (EOF)
    if is_eof then
        local cjson = require "cjson.safe";
        local body = ngx.ctx.buffered_body;
        local data, err = cjson.decode(body);

        if data and not err then
            -- --- Core Logic ---
            
            -- Get the original request URI (before rewrite)
            local original_uri = ngx.var.request_uri or ngx.var.uri or "";
            local upstream_uri = ngx.var.upstream_uri or ngx.var.uri or "";
            
            -- Extract the prefix that was rewritten (e.g., /impresso-images/ -> /iiif/3/)
            -- The upstream URL reconstruction: scheme + host + (original_uri with /info.json stripped)
            -- local scheme = ngx.var.upstream_scheme or "https";
            local scheme = "http";
            if ngx.var.https == "on" or ngx.req.get_headers()["x-forwarded-proto"] == "https" then
                scheme = "https";
            end

            local http_host = ngx.var.http_host or ngx.var.host or "localhost";
            
            -- Get upstream proxy pass URL from the proxy directive
            -- We construct: scheme://host + original_uri without /info.json
            local id_value = scheme .. "://" .. http_host .. original_uri:gsub("/info%.json$", "");

            if data.id then
              ngx.log(ngx.NOTICE, "Replacing 'id' field " .. data.id .. " with upstream URL " .. id_value);
              data.id = id_value;
            end
            if data["@id"] then
              ngx.log(ngx.NOTICE, "Replacing '@id' field " .. data["@id"] .. " with upstream URL " .. id_value);
              data["@id"] = id_value;
            end
            -- --- End Core Logic ---

            local new_body, encode_err = cjson.encode(data);

            if new_body then
                -- Replace the buffer (ngx.arg[1] which was cleared)
                -- with the new, modified JSON body.
                ngx.arg[1] = new_body;
            else
                ngx.log(ngx.ERR, "Failed to encode modified JSON: ", encode_err);
            end
        else
            ngx.log(ngx.ERR, "Failed to decode buffered JSON: ", err);
            -- If decoding fails, you can choose to send the original
            -- buffered body or an error message. Here we send the original.
            ngx.arg[1] = body;
        end
    end
end
-- If it is not JSON, ngx.arg[1] (the original chunk) is passed through unmodified.
