// 导出所有处理器
const loginGame = require('./user/login_game');
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
const getEquipInfo = require('./equipment/get_equip_info');
const equipItem = require('./equipment/equip_item');
const unequipItem = require('./equipment/unequip_item');
const getEquipLevelInfo = require('./equipment/get_equip_level_info');
const upgradeEquipLevel = require('./equipment/upgrade_equip_level');


// 导入邮件处理器
const getMailList = require('./mail/get_mail_list');
const readMail = require('./mail/read_mail');
const claimMailItems = require('./mail/claim_mail_items');
const deleteMail = require('./mail/delete_mail');

// 导入伙伴处理器
const getPartnerList = require('./partner/get_partner_list');
const levelUpPartner = require('./partner/level_up_partner');
const starUpPartner = require('./partner/star_up_partner');
const unlockPartner = require('./partner/unlock_partner');

// 导入地图处理器
const getMapInfo = require('./map/get_map_info');
const rollDice = require('./map/roll_dice');
const handleCellEvent = require('./map/handle_cell_event');
const claimReward = require('./map/claim_reward');

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
    loginGame,
    getUserInfo,
    getUserCards,
    
    // 系统相关
    sendHeartbeat,
    
    // GM相关
    gmCommand,
    
    // 新增分解物品处理器
    decomposeItem,
    
    // 装备相关处理器
    getEquipInfo,
    equipItem,
    unequipItem,
    getEquipLevelInfo,
    upgradeEquipLevel,

    // 邮件处理器
    getMailList,
    readMail,
    claimMailItems,
    deleteMail,
    
    // 伙伴相关处理器
    getPartnerList,
    levelUpPartner,
    starUpPartner,
    unlockPartner,
    
    // 地图相关处理器
    getMapInfo,
    rollDice,
    handleCellEvent,
    claimReward
}; 