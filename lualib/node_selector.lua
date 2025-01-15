local M = {}

-- 轮询选择器
function M.round_robin(nodes, next_index)
    local node = nodes[next_index]
    next_index = next_index % #nodes + 1
    if next_index == 0 then next_index = 1 end
    return node, next_index
end

-- 根据连接ID选择
function M.connection_hash(nodes, client_id)
    local index = (client_id % #nodes) + 1
    return nodes[index]
end

return M 