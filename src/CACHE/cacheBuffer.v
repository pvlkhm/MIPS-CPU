module cacheBuffer(
    input clk, rst,
    input write, // сигнал обновления регистров буфера записи
    input readRAMBuffer, // чтение из буфера записи
    input forceWrite, // сигнал принудительной записи (классическая запись в кэш)
    input ramBufferWrite, // сигнал записи в RAM-буфер
    input pos, // канал записи (0-ой (правый) или 1-ый (левый))
    input [31:0] address, dataIn,
    output hit, full, empty, // full — переполнение буфера записи в RAM; empty — буфер пуст
    output [31:0] data,
    output [31:0] addressToMemory, dataToMemory
);
    wire hitInQueue, hitInCache, hitInCacheChannel, hitInBuffer; // HIT'ы в разных частях конвейера
    wire [31:0] dataInCache, dataInBuffer; // data из таблицы даных кэша
    // "Разбор" ВХОДЯЩЕГО адреса на составляющие
    //         24bit         3bit   3bit    2bit
    // |        tag        | line | word | offset |
    wire    [23:0]  tag = address[31:8];
    wire    [2:0]   line = address[7:5];
    wire    [2:0]   word = address[4:2];
    wire    [1:0]   offset = address[1:0];
    // Регистры хранения данных для записи (конвейер записи) QUEUE
    // Разрешение (1) + Канал (1) + Запись в кэш (1) + Адрес (32) + Данные (32)
    reg updateEnableQueue, posQueue, forceWriteQueue;
    reg [32:0] addressQueue; // Бит актуальности + адрес
    reg [31:0] dataInQueue; // Данные
    // Сброс + В очередь на запись, если сигнал записи
    always @(posedge clk) begin
        if (rst)
            {updateEnableQueue, posQueue, forceWriteQueue, addressQueue, dataInQueue} <= 68'd0;
        else if (write) begin
            updateEnableQueue <= hit;
            posQueue <= pos;
            forceWriteQueue <= forceWrite;
            addressQueue <= {1'b1, address};
            dataInQueue <= dataIn;
        end
    end
    // "Разбор" ХРАНИМОГО адреса на составляющие
    wire            actualQueue = addressQueue[32];
    wire    [23:0]  tagQueue = addressQueue[31:8];
    wire    [2:0]   lineQueue = addressQueue[7:5];
    wire    [2:0]   wordQueue = addressQueue[4:2];

    assign hitInQueue  = (address == addressQueue[31:0]) && actualQueue; // HIT в очереди на запись
    // Подключение таблицы кэша (Управление + Данные)
    tableControl tableControl(
        .clk(clk), .rst(rst), .write(forceWriteQueue), .pos(posQueue), .lineWrite(lineQueue), .lineRead(line), 
        .tagWrite(tagQueue), .tagRead(tag), .hit(hitInCache), .channel(hitInCacheChannel)
    );
    tableData tableData(
        .clk(clk), .rst(rst), .update(updateEnableQueue), .channel(hitInCacheChannel), 
        .write(forceWriteQueue), .pos(posQueue), 
        .lineWrite(lineQueue), .lineRead(line), .wordWrite(wordQueue), .wordRead(word), 
        .dataIn(dataInQueue), .data(dataInCache)
    );
    memoryBuffer memoryBuffer(
        .clk(clk), .rst(rst), .address(address), .dataIn(dataIn), .write(ramBufferWrite), .read(readRAMBuffer),
        .dataHit(dataInBuffer), .hit(hitInBuffer), .full(full), .empty(empty),
        .addressToMemory(addressToMemory), .dataToMemory(dataToMemory)
    );


    assign hit = hitInQueue || hitInCache || hitInBuffer; // HIT в CPU при совпадении 
    
    // data НУЖНО ВЕРНУТЬ ПО HIT-ам! 
    assign data = hitInBuffer ? dataInBuffer : hitInQueue ? dataInQueue : dataInCache;
    


endmodule