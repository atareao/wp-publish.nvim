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
    local base_url = config.url:gsub("/posts$", "/podcast")
    local search_url = string.format("%s?meta_key=number&meta_value=%s", base_url, episode_number)
    
    local auth = vim.base64.encode(config.user .. ":" .. config.pass)
    
    local cmd = string.format("curl -s -H 'Authorization: Basic %s' '%s'", auth, search_url)
    
    local result = vim.fn.system(cmd)
    local data = vim.fn.json_decode(result)
    
    if data and type(data) == "table" and #data > 0 then
        return data[1].id
    end
    return nil
end

local function get_config()
    local cfg = {
        url = os.getenv("WP_URL"),
        user = os.getenv("WP_USER"),
        pass = os.getenv("WP_APP_PASS"),
    }
    return cfg
end

function M.publish()
    local config = get_config()

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
    
    vim.notify("🚀 Publishing to ...", vim.log.levels.INFO)

    vim.fn.jobstart({
        "curl", "-s", "-X", "POST", url,
        "-H", "Authorization: Basic " .. auth,
        "-H", "Content-Type: application/json",
        "-d", json_payload
    }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                for _, line in ipairs(data) do
                    if line ~= "" then table.insert(stdout_data, line) end
                end
            end
        end,
        on_exit = function(_, code)
            if code == 0 then
                local response = table.concat(stdout_data, "")
                local decoded = vim.fn.json_decode(response)
                
                if decoded and decoded.id then
                    local action = post_id and "Updated" or "Created"
                    vim.notify("✅ " .. action .. " successfully! ID: " .. decoded.id, vim.log.levels.INFO)
                else
                    vim.notify("⚠️ Sent, but the response looked strange.", vim.log.levels.WARN)
                end
            else
                vim.notify("❌ Networking error: curl failed with code " .. code, vim.log.levels.ERROR)
            end
        end
    })
end

return M
