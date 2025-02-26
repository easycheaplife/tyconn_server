// 导出所有处理器
const getBagInfo = require('./bag/get_bag_info');
const expandBag = require('./bag/expand_bag');
const sortBag = require('./bag/sort_bag');
const useItem = require('./item/use_item');
const getUserInfo = require('./user/get_user_info');
const getUserCards = require('./user/get_user_cards');
const sendHeartbeat = require('./system/heartbeat');
const gmCommand = require('./gm/gm_command');

module.exports = {
    // 背包相关
    getBagInfo,
    expandBag,
    sortBag,
    
    // 物品相关
    useItem,
    
    // 用户相关
    getUserInfo,
    getUserCards,
    
    // 系统相关
    sendHeartbeat,
    
    // GM相关
    gmCommand
}; 