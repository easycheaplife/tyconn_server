// 导出所有处理器
const getBagInfo = require('./bag/get_bag_info');
const expandBag = require('./bag/expand_bag');

module.exports = {
    // 背包相关
    getBagInfo: require('./bag/get_bag_info'),
    expandBag: require('./bag/expand_bag'),
    
    // 物品相关
    useItem: require('./item/use_item'),
    
    // 用户相关
    getUserInfo: require('./user/get_user_info'),
    getUserCards: require('./user/get_user_cards'),
    
    // 系统相关
    sendHeartbeat: require('./system/heartbeat'),
    
    // GM相关
    gm_command: require('./gm/gm_command')
}; 