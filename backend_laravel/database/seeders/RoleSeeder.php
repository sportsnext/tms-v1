<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('roles')->updateOrInsert(
            ['id' => 1],
            ['role_name' => 'Super Admin']
        );

        DB::table('roles')->updateOrInsert(
            ['id' => 2],
            ['role_name' => 'Admin']
        );

        DB::table('roles')->updateOrInsert(
            ['id' => 3],
            ['role_name' => 'Franchise']
        );

        DB::table('roles')->updateOrInsert(
            ['id' => 4],
            ['role_name' => 'Scorer']
        );

        DB::table('roles')->updateOrInsert(
            ['id' => 5],
            ['role_name' => 'User']
        );
    }
}
