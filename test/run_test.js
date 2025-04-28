const LoginClient = require('./lib/login_client');
const config = require('./config/config');
const { parseArgs } = require('./lib/cli');

// System tests
const TokenTest = require('./cases/system/token_test');
const HeartbeatTest = require('./cases/system/heartbeat_test');

// User tests
const LoginGameTest = require('./cases/user/login_game_test');
const UserInfoTest = require('./cases/user/user_info_test');
const UserCardsTest = require('./cases/user/user_cards_test');
const LoginTest = require('./cases/user/login_test');

// Bag tests
const BagInfoTest = require('./cases/bag/bag_info_test');
const ExpandBagTest = require('./cases/bag/expand_bag_test');
const SortBagTest = require('./cases/bag/sort_bag_test');
const MoveItemTest = require('./cases/bag/move_item_test');

// Item tests
const UseItemTest = require('./cases/item/use_item_test');
const ComposeItemTest = require('./cases/item/compose_item_test');
const DecomposeItemTest = require('./cases/item/decompose_item_test');

// Equipment tests
const EquipInfoTest = require('./cases/equip/equip_info_test');
const EquipItemTest = require('./cases/equip/equip_item_test');
const UnequipItemTest = require('./cases/equip/unequip_item_test');
const EquipLevelInfoTest = require('./cases/equip/equip_level_info_test');
const UpgradeEquipLevelTest = require('./cases/equip/upgrade_equip_level_test');
const EquipRandomTest = require('./cases/equip/equip_random_test');

// Mail tests
const GetMailListTest = require('./cases/mail/get_mail_list_test');
const ReadMailTest = require('./cases/mail/read_mail_test');
const ClaimMailItemsTest = require('./cases/mail/claim_mail_items_test');
const DeleteMailTest = require('./cases/mail/delete_mail_test');
const GmMailTest = require('./cases/mail/gm_mail_test');

// Partner tests
const GetPartnerListTest = require('./cases/partner/get_partner_list_test');
const LevelUpPartnerTest = require('./cases/partner/level_up_partner_test');
const StarUpPartnerTest = require('./cases/partner/star_up_partner_test');
const UnlockPartnerTest = require('./cases/partner/unlock_partner_test');

// Map tests
const GetMapInfoTest = require('./cases/map/get_map_info_test');
const RollDiceTest = require('./cases/map/roll_dice_test');
const HandleCellEventTest = require('./cases/map/handle_cell_event_test');
const ClaimRewardTest = require('./cases/map/claim_reward_test');

// GM tests
const GMCommandTest = require('./cases/gm/gm_command_test');

// 所有测试用例
const ALL_TESTS = {
    // System tests
    token: TokenTest,
    heartbeat: HeartbeatTest,

    // User tests
    login_game: LoginGameTest,
    user_info: UserInfoTest,
    user_cards: UserCardsTest,
    login: LoginTest,

    // Bag tests
    bag_info: BagInfoTest,
    expand_bag: ExpandBagTest,
    sort_bag: SortBagTest,
    move_item: MoveItemTest,

    // Item tests
    use_item: UseItemTest,
    compose_item: ComposeItemTest,
    decompose_item: DecomposeItemTest,

    // Equipment tests
    equip_info: EquipInfoTest,
    equip_item: EquipItemTest,
    unequip_item: UnequipItemTest,
    equip_level_info: EquipLevelInfoTest,
    upgrade_equip_level: UpgradeEquipLevelTest,
    equip_random: EquipRandomTest,

    // Mail tests
    get_mail_list: GetMailListTest,
    read_mail: ReadMailTest,
    claim_mail_items: ClaimMailItemsTest,
    delete_mail: DeleteMailTest,
    gm_mail: GmMailTest,

    // Partner tests
    get_partner_list: GetPartnerListTest,
    level_up_partner: LevelUpPartnerTest,
    star_up_partner: StarUpPartnerTest,
    unlock_partner: UnlockPartnerTest,
    
    // Map tests
    get_map_info: GetMapInfoTest,
    roll_dice: RollDiceTest,
    handle_cell_event: HandleCellEventTest,
    claim_reward: ClaimRewardTest,

    // GM tests
    gm_command: GMCommandTest,
};

async function runTests() {
    const args = parseArgs();
    console.log('\nStarting tests...');
    let passed = 0;
    let failed = 0;
    // Track failed test cases
    const failedTests = [];

    try {
        // 获取token和服务器信息
        let token, gateInfo;
        if (args.token) {
            // 使用命令行提供的token
            token = args.token;
            gateInfo = {
                protocol: config.protocol,
                host: args.server || config.loginHost,
                port: args.port || config.loginPort
            };
        } else {
            // 登录获取token
            console.log('Logging in...');
            const loginClient = new LoginClient();
            const loginResult = await loginClient.login(
                config.testAccount,
                config.testPassword
            );
            token = loginResult.token;
            gateInfo = loginResult.gateInfo;
            console.log('Login successful');
        }

        // 确定要运行的测试用例
        let testsToRun = [];
        if (args.test) {
            // 运行指定的测试
            const TestClass = ALL_TESTS[args.test];
            if (!TestClass) {
                throw new Error(`Unknown test case: ${args.test}`);
            }
            testsToRun = [new TestClass()];
        } else {
            // 运行所有测试
            testsToRun = Object.values(ALL_TESTS).map(TestClass => new TestClass());
        }

        // 运行测试用例
        for (const testCase of testsToRun) {
            console.log(`\nRunning test: ${testCase.name}`);
            const result = await testCase.run(token, gateInfo);
            if (result) {
                passed++;
            } else {
                failed++;
                // Add the failing test name to our list
                failedTests.push(testCase.name);
            }
        }

        // 打印测试结果
        console.log('\nTest Summary:');
        console.log(`Total: ${testsToRun.length}`);
        console.log(`Passed: ${passed}`);
        console.log(`Failed: ${failed}`);
        
        // 打印失败的测试案例名称
        if (failedTests.length > 0) {
            console.log('\nFailed tests:');
            failedTests.forEach((testName, index) => {
                console.log(`${index + 1}. ${testName}`);
            });
        }

        // 如果有失败的测试，退出码设为1
        if (failed > 0) {
            process.exit(1);
        }

    } catch (error) {
        console.error('\nTest runner failed:', error);
        process.exit(1);
    }
}

// 运行测试
runTests().catch(error => {
    console.error('Unhandled error:', error);
    process.exit(1);
}); 