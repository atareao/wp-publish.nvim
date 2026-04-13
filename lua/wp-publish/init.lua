local M = {}

function M.update_timestamp()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local last_line = math.min(20, vim.api.nvim_buf_line_count(0)) -- Only check the first 20 lines
    local lines = vim.api.nvim_buf_get_lines(0, 0, last_line, false)
    local current_time = os.date("%Y-%m-%dT%H:%M:%S")

    for i, line in ipairs(lines) do
        -- Search for the line starting with 'updated:'
        if line:match("^updated:") then
            local new_line = "updated: " .. current_time
            vim.api.nvim_buf_set_lines(0, i - 1, i, false, { new_line })
            -- Restore cursor so it doesn't jump
            vim.api.nvim_win_set_cursor(0, cursor_pos)
            break
        end
    end
end

-- Basic YAML frontmatter parser
local function parse_frontmatter()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local frontmatter = {}
    local content_start = 0
    
    if lines[1] ~= "---" then return nil end

    for i = 2, #lines do
        if lines[i] == "---" then
            content_start = i + 1
            break
        end
        local key, val = lines[i]:match("^(%w+):%s*(.*)$")
        if key then
            -- Clean strings or handle basic lists if necessary
            frontmatter[key] = val:gsub('^"(.*)"$', "%1")
        end
    end

    local content = table.concat(vim.api.nvim_buf_get_lines(0, content_start - 1, -1, false), "\n")
    return frontmatter, content
end

-- Helper to find post ID by episode number
local function find_post_id(config, episode_number)
    -- We filter by the 'number' meta field
    -- Note: This requires the REST API to allow filtering by meta
    local search_url = string.format("%s?meta_key=number&meta_value=%s",
        config.url:gsub("/posts$", "/podcast"),
        episode_number)
    
    local auth = vim.base64.encode(config.config_user .. ":" .. config.pass)
    local cmd = string.format("curl -s -H 'Authorization: Basic %s' '%s'", auth, search_url)
    
    local result = vim.fn.system(cmd)
    local data = vim.fn.json_decode(result)
    
    if data and #data > 0 then
        return data[1].id
    end
    return nil
end

function M.publish()
    local config = {
        url = os.getenv("WP_URL"),
        user = os.getenv("WP_USER"),
        pass = os.getenv("WP_APP_PASS"),
    }

    -- VALIDATION: Check if variables are missing BEFORE using them
    if not config.url then
        vim.notify("[wp-publish] Error: WP_URL is not set in your environment.", vim.log.levels.ERROR)
        return
    end
    if not config.user then
        vim.notify("[wp-publish] Error: WP_USER is not set.", vim.log.levels.ERROR)
        return
    end
    if not config.pass then
        vim.notify("[wp-publish] Error: WP_APP_PASS is not set.", vim.log.levels.ERROR)
        return
    end
    
    local frontmatter, content = parse_frontmatter() -- (Assume previous parser function)
    local url = config.url
    local is_podcast = frontmatter.season and frontmatter.episode
    local post_id = nil

    if is_podcast then
        url = url:gsub("/posts$", "/podcast")
        -- Search if it exists
        post_id = find_post_id(config, frontmatter.episode)
    end

    -- If post_id exists, we append it to the URL to perform an UPDATE
    if post_id then
        url = url .. "/" .. post_id
    end

    local payload = {
        title = frontmatter.title,
        content = content,
        status = "publish",
    }

    if is_podcast then
        payload.meta = {
            season = tonumber(frontmatter.season),
            number = tonumber(frontmatter.episode)
        }
    end

    local json_payload = vim.fn.json_encode(payload)
    local auth = vim.base64.encode(config.user .. ":" .. config.pass)
    
    -- Using POST with an ID in the URL tells WordPress to update the existing record
    local cmd = string.format(
        "curl -s -X POST %s -H 'Authorization: Basic %s' -H 'Content-Type: application/json' -d %s",
        url, auth, vim.fn.shellescape(json_payload)
    )

    vim.fn.jobstart(cmd, {
        on_exit = function(_, code)
            local action = post_id and "Updated" or "Created"
            if code == 0 then
                vim.notify(action .. " " .. (is_podcast and "Podcast" or "Post"), vim.log.levels.INFO)
            else
                vim.notify("Error during " .. action, vim.log.levels.ERROR)
            end
        end
    })
end

return M
