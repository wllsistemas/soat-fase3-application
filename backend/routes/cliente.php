<?php

use App\Http\ClienteApi;
use Illuminate\Support\Facades\Route;

Route::post('/cliente', [ClienteApi::class, 'create']);

Route::get('/cliente', [ClienteApi::class, 'read']);
Route::get('/cliente/{uuid}', [ClienteApi::class, 'readOne'])->middleware(DocumentoObrigatorioMiddleware::class);

Route::put('/cliente/{uuid}', [ClienteApi::class, 'update']);
Route::delete('/cliente/{uuid}', [ClienteApi::class, 'delete']);
