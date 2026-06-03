<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('venue_grounds', function (Blueprint $table) {
            $table->id();

            $table->foreignId('venue_id')
                  ->constrained('venues')
                  ->cascadeOnDelete();

            $table->string('ground_name');
            $table->string('ground_type')->nullable();
            $table->integer('court_count')->default(1);

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('venue_grounds');
    }
};
