const LoginClient = require('./lib/login_client');
const config = require('./config/config');
const { parseArgs } = require('./lib/cli');
const LoginGameTest = require('./cases/login_game_test');
const UserInfoTest = require('./cases/user_info_test');
const HeartbeatTest = require('./cases/heartbeat_test');
const UserCardsTest = require('./cases/user_cards_test');
const BagInfoTest = require('./cases/bag_info_test');
const UseItemTest = require('./cases/use_item_test');
const TokenTest = require('./cases/token_test');
const LoginTest = require('./cases/login_test');
const ExpandBagTest = require('./cases/expand_bag_test');
const GMCommandTest = require('./cases/gm_command_test');
const SortBagTest = require('./cases/sort_bag_test');
const MoveItemTest = require('./cases/move_item_test');
const ComposeItemTest = require('./cases/compose_item_test');
const DecomposeItemTest = require('./cases/decompose_item_test');
const EquipInfoTest = require('./cases/equip_info_test');
const EquipItemTest = require('./cases/equip_item_test');
const UnequipItemTest = require('./cases/unequip_item_test');
const UpgradeEquipLevelTest = require('./cases/upgrade_equip_level_test');
const EquipLevelInfoTest = require('./cases/equip_level_info_test');
const EquipRandomTest = require('./cases/equip_random_test');
const GetMailListTest = require('./cases/get_mail_list_test');
const ReadMailTest = require('./cases/read_mail_test');
const ClaimMailItemsTest = require('./cases/claim_mail_items_test');
const DeleteMailTest = require('./cases/delete_mail_test');
const GmMailTest = require('./cases/gm_mail_test');
const GetPartnerListTest = require('./cases/get_partner_list_test');
const LevelUpPartnerTest = require('./cases/level_up_partner_test');
const StarUpPartnerTest = require('./cases/star_up_partner_test');
const UnlockPartnerTest = require('./cases/unlock_partner_test');


// 所有测试用例
const ALL_TESTS = {
    login_game: LoginGameTest,
    user_info: UserInfoTest,
    heartbeat: HeartbeatTest,
    user_cards: UserCardsTest,
    bag_info: BagInfoTest,
    use_item: UseItemTest,
    token: TokenTest,
    login: LoginTest,
    expand_bag: ExpandBagTest,
    gm_command: GMCommandTest,
    sort_bag: SortBagTest,
    move_item: MoveItemTest,
    compose_item: ComposeItemTest,
    decompose_item: DecomposeItemTest,
    equip_info: EquipInfoTest,
    /*
    equip_item: EquipItemTest,
    unequip_item: UnequipItemTest,
    equip_random: EquipRandomTest,
    equip_level_info: EquipLevelInfoTest,
    upgrade_equip_level: UpgradeEquipLevelTest,
    */
    get_mail_list: GetMailListTest,
    read_mail: ReadMailTest,
    claim_mail_items: ClaimMailItemsTest,
    delete_mail: DeleteMailTest,
    gm_mail: GmMailTest,
    
    get_partner_list: GetPartnerListTest,
    level_up_partner: LevelUpPartnerTest,
    star_up_partner: StarUpPartnerTest,
    unlock_partner: UnlockPartnerTest,
};

async function runTests() {
    const args = parseArgs();
    console.log('\nStarting tests...');
    let passed = 0;
    let failed = 0;

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
            const result = await testCase.run(token, gateInfo);
            if (result) {
                passed++;
            } else {
                failed++;
            }
        }

        // 打印测试结果
        console.log('\nTest Summary:');
        console.log(`Total: ${testsToRun.length}`);
        console.log(`Passed: ${passed}`);
        console.log(`Failed: ${failed}`);

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