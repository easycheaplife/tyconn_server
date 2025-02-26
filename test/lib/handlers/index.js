// 导出所有处理器
const getBagInfo = require('./bag/get_bag_info');
const expandBag = require('./bag/expand_bag');
const sortBag = require('./bag/sort_bag');
const moveItem = require('./bag/move_item');
const useItem = require('./item/use_item');
const composeItem = require('./item/compose_item');
const getUserInfo = require('./user/get_user_info');
const getUserCards = require('./user/get_user_cards');
const sendHeartbeat = require('./system/heartbeat');
const gmCommand = require('./gm/gm_command');
const decomposeItem = require('./item/decompose_item');

module.exports = {
    // 背包相关
    getBagInfo,
    expandBag,
    sortBag,
    moveItem,
    
    // 物品相关
    useItem,
    composeItem,
    
    // 用户相关
    getUserInfo,
    getUserCards,
    
    // 系统相关
    sendHeartbeat,
    
    // GM相关
    gmCommand,
    
    // 新增分解物品处理器
    decomposeItem,
}; 