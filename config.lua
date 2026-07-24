return {
    framework = 'auto',
    locale = 'en',
    interaction = 'ox_target',
    debug = false,
    bags = {
        patrolbag = {
            label = 'Patrol Bag',
            item = 'patrolbag',
            slots = 25,
            weight = 25000,
            carry = 'v_ret_gc_bag02',
            items = {
                radio = 1,
                handcuffs = 2,
                bandage = 5,
            },
        },

        firstaid = {
            label = 'Erste-Hilfe-Tasche',
            item = 'firstaid_bag',
            slots = 20,
            weight = 20000,
            carry = 'xm_prop_x17_bag_med_01a',
            items = {
                bandage = 10,
                ifaks = 2,
            },
        },

        manv = {
            label = 'MANV-Tasche',
            item = 'manv',
            slots = 40,
            weight = 40000,
            carry = 'prop_big_bag_01',
            items = {
                bandage = 20,
                ifaks = 6,
                painkillers = 10,
            },
        },

        kfz_kit = {
            label = 'KFZ-Verbandkasten',
            item = 'kfz_kit',
            slots = 10,
            weight = 8000,
            carry = 'prop_ld_case_01',
            items = {
                bandage = 2,
            },
        },
    },

    points = {
        {
            label = 'Polizei-Ausgabe',
            coords = vec4(454.0644, -980.2876, 30.6896, 95.1318),
            jobs = { police = 0 },
            bags = { 'patrolbag', 'firstaid' },
            ped = 's_m_y_cop_01',
        },

        {
            label = 'Rettungsdienst-Ausgabe',
            coords = vec4(306.4, -601.3, 43.3, 70.0),
            jobs = { ambulance = 0 },
            bags = { 'manv', 'firstaid' },
            prop = 'xm_prop_x17_bag_med_01a',
        },

        {
            label = 'Verbandkasten',
            coords = vec4(-48.2, -1757.8, 29.4, 50.0),
            bags = { 'kfz_kit' },
        },
    },
}