/*
    Кэш данных
    * 2 канала
    * 8 линий по 8 слов
    * Конвейер записи
    * Буфер записи 
*/
module cache(
    input rst, clk,
    input [31:0] address, writeData,
    input writeMem, readMem,
    output stopCPU,
    output [31:0] data
);
    wire hit, full, empty, forceWrite; // forceWrite — запись после MISS (принудительная в кэш)
    wire cacheWrite, ramBufferWrite; // Сигналы записи в кэш и буфер записи в RAM
    wire [31:0] addressToRAMRead, addressToRAMWrite, addressToRAM, dataToRAM, dataFromRAM;
    wire [31:0] addressToCache, dataToCache;
    wire readRAMBuffer, writeRAMFromBuffer; // Разрешение подгрузки новых данных в RAM; И записи в RAM
    wire posToCache; // Выбор канала для записи в кэш (0 или 1, правый или левый)
    reg [7:0] pos; // Позиция для записи (0/1 — правый/левый канал буфера)
    reg ramSync; // Идет обмен в RAM
    reg [2:0] ramPumpCounter; // Счетчик обмена с RAM (7 — выкл / 0+ — вкл)

    datamem dm(.clk(clk), .writeMem(writeRAMFromBuffer), .addr(addressToRAM), .writeData(dataToRAM), .data(dataFromRAM));
    cacheBuffer cb(
        .clk(clk), .rst(rst), .write(cacheWrite), .readRAMBuffer(readRAMBuffer),
        .forceWrite(forceWrite), .ramBufferWrite(ramBufferWrite), .pos(posToCache),
        .address(addressToCache), .dataIn(dataToCache), .hit(hit), .full(full), .empty(empty),
        .data(data), .addressToMemory(addressToRAMWrite), .dataToMemory(dataToRAM)
    );

    assign addressToCache = ramSync ? addressToRAM : address; // Если обмен с RAM => адрес порции данных
    assign dataToCache = ramSync ? dataFromRAM : writeData; // Если обмен с RAM => данные из нее

    assign addressToRAMRead = { address[31:5], ramPumpCounter[2:0], 2'b00 }; // Начинаем брать 8 адресов по тегу
    assign addressToRAM = ramSync ? addressToRAMRead : addressToRAMWrite;

    assign ramBufferWrite = ramSync ? 1'd0 : cacheWrite; // Если обмен с RAM => не нужно писать в буфер записи RAM
    assign cacheWrite = ramSync ? 1'd1 : full ? 1'd0 : writeMem;
    assign forceWrite = ramSync;
    assign posToCache = pos[address[7:5]]; // [7:5] - номер строки для(в) кэша

    assign readRAMBuffer = ~ramSync;
    assign writeRAMFromBuffer = ~ramSync && ~empty;

    // Требуется чтение и нет HIT'а => остановка конвейера
    // Чтение линии из RAM => остановка конвейера
    // Запись, но буфер записи полон => остановка конвейера
    assign stopCPU = (readMem && !hit) || ramSync || (writeMem && full); 


    // При MISS'е необходимо запросить данные из RAM (8 слов)
    // 0-1-2-3-4-5-6-7      такты: Запрос значений в RAM
    always @(posedge clk) begin
        if (rst) begin
            ramPumpCounter <= 3'd7; // Начальное состояние
            ramSync <= 1'd0;
            pos <= 8'd0;
        end
        else if (readMem) begin // ЧТЕНИЕ
            if (~hit && ramPumpCounter == 3'd7) begin // если ЧТЕНИЕ + MISS (+ нет обмена с RAM)
                ramPumpCounter <= 3'd0;
                ramSync <= 1'd1;
                pos[address[7:5]] <= ~pos[address[7:5]];
            end
            else if (ramPumpCounter != 3'd7) begin
                ramPumpCounter += 3'b1;
            end
            else
                ramSync <= 1'd0;
        end
    end

endmodule