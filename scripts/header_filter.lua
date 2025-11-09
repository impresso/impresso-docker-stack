local content_type = ngx.header["Content-Type"] or "";

-- Check if it is JSON, and if so, initialize the buffer in ngx.ctx
if string.find(content_type, "application/ld+json", 1, true) then
    -- Initialize the body buffer in the request context
    ngx.ctx.buffered_body = "";
    -- Reset Content-Length because the body size might change
    ngx.header.content_length = nil;
end
