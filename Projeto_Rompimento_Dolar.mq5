//+------------------------------------------------------------------+
//|                                     Projeto_Rompimento_Dolar.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                                 Julian R Valerio |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

CTrade DayTrade;

input string Inicio = "09:16";
input string Termino = "16:00";
input string Fechamento = "17:00";
input int Limite_Gain_Diario = 300;
input int Limite_Loss_Diario = 300;
input int Gain_Operacao = 15;
input int Loss_Operacao = 15;

//Armazenar data e hora
MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual, dia; 

bool operacao_diaria = false, limite_atingido = false;
int contarCandle = 0;
int barraOperacao = 0;


double saldo_operacao = 0.0, saldo_diario=0.0, saldo_abertura = 0.0;

int OnInit(){
   //Obter Saldo da Abertura do Dia
   saldo_abertura = AccountInfoDouble(ACCOUNT_BALANCE);
   
   //conversao para mql
   TimeToStruct(StringToTime(Inicio), horario_inicio);
   TimeToStruct(StringToTime(Termino), horario_termino);
   TimeToStruct(StringToTime(Fechamento), horario_fechamento);
   
   if(horario_inicio.hour > horario_termino.hour || (horario_inicio.hour == horario_termino.hour && horario_inicio.min > horario_termino.min)){
      printf("Parametros de entrada inválidos!");
      return INIT_FAILED;         
   }   
   if(horario_termino.hour > horario_fechamento.hour || (horario_termino.hour == horario_fechamento.hour && horario_termino.min > horario_fechamento.min)){
      printf("Parametros de entrada inválidos!");
      return INIT_FAILED;            
   }
   return INIT_SUCCEEDED;
   
   EventSetTimer(60);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   //Obter ultimo valor negociado
   MqlTick ultimoTick;
   SymbolInfoTick(_Symbol,ultimoTick);
   
   if(HorarioFechamento()){
      operacao_diaria = false;
      contarCandle = 0;
      barraOperacao = 0;
      limite_atingido = false;
      saldo_diario = 0.0;
      saldo_operacao = 0.0;
   }
   saldo_operacao = AccountInfoDouble(ACCOUNT_PROFIT);
   Comment("Saldo Diario = "+saldo_diario, "\n Saldo Operacao = "+ saldo_operacao);
   //
   //Contar Candles   
   MqlRates preco[];
   ArraySetAsSeries(preco,true);
   CopyRates(_Symbol, PERIOD_M15,0,3,preco);
   static datetime ultimaVerificacaoTempo;
   datetime tempoCandleCorrente;
   tempoCandleCorrente = preco[0].time;
   if(tempoCandleCorrente != ultimaVerificacaoTempo){
      ultimaVerificacaoTempo = tempoCandleCorrente;
      contarCandle++;
   }
   
   //Ordem de compra
   if(PositionsTotal()==0 && ultimoTick.last > iHigh(_Symbol,PERIOD_M15,1) && HorarioEntrada()== true
    && contarCandle > barraOperacao && operacao_diaria==false && limite_atingido == false 
    && saldo_diario < Limite_Gain_Diario && saldo_diario > -Limite_Loss_Diario){
      
      DayTrade.Buy(1,_Symbol,ultimoTick.last);  
      //operacao_diaria = true;    
      barraOperacao = contarCandle;
   }
   
   //Ordem de Venda
   if(PositionsTotal()==0 && ultimoTick.last < iLow(_Symbol,PERIOD_M15,1) && HorarioEntrada()== true 
      && contarCandle > barraOperacao && operacao_diaria==false && limite_atingido == false 
      && saldo_diario < Limite_Gain_Diario && saldo_diario > -Limite_Loss_Diario){
     
      DayTrade.Sell(1,_Symbol,ultimoTick.last);      
      //operacao_diaria = true;
      barraOperacao = contarCandle;
   }
   
   for(int i = PositionsTotal(); i>=0; i--){//Cataloga todas as operações abertas
      if(PositionGetSymbol(i)==_Symbol){//Filtra pelo ativo atual
      //Filtra operações de compra
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            EncerrarCompra();
                                 
        }
        //Filtra operações de venda
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            EncerrarVenda();
        }
      }      
   }  
   
}

bool EncerrarCompra(){
   if(saldo_diario + saldo_operacao >= Limite_Gain_Diario || saldo_diario + saldo_operacao <= -Limite_Loss_Diario){
      DayTrade.PositionClose(_Symbol);  
      limite_atingido = true;
      saldo_diario += saldo_operacao;
      return true;
   } 
   if(PositionGetDouble(POSITION_PRICE_CURRENT) > (PositionGetDouble(POSITION_PRICE_OPEN)+Gain_Operacao) ){
      DayTrade.PositionClose(_Symbol);               
      saldo_diario += saldo_operacao;
      if(saldo_diario >= Limite_Gain_Diario || saldo_diario <= -Limite_Loss_Diario){
         limite_atingido = true;
      }
      return true;
   }
   if(PositionGetDouble(POSITION_PRICE_CURRENT) < (PositionGetDouble(POSITION_PRICE_OPEN)-Loss_Operacao) ){
      DayTrade.PositionClose(_Symbol);               
      saldo_diario += saldo_operacao;
      if(saldo_diario >= Limite_Gain_Diario || saldo_diario <= -Limite_Loss_Diario){
         limite_atingido = true;
      }
      return true;
   } 
   return false;

}

bool EncerrarVenda(){
   if(saldo_diario <= -Limite_Loss_Diario || saldo_diario + saldo_operacao <= -Limite_Loss_Diario ||
      saldo_diario >= Limite_Gain_Diario || saldo_diario + saldo_operacao >= Limite_Gain_Diario){
      DayTrade.PositionClose(_Symbol);  
      limite_atingido = true;
      saldo_diario += saldo_operacao;
      return true;
   }
   if(PositionGetDouble(POSITION_PRICE_CURRENT) < (PositionGetDouble(POSITION_PRICE_OPEN)-Gain_Operacao)){//Calcula se excedeu a distância para mover o SL               
      DayTrade.PositionClose(_Symbol);
      saldo_diario += saldo_operacao;
      if(saldo_diario <= -Limite_Loss_Diario || saldo_diario >= Limite_Gain_Diario){
         limite_atingido = true;
      }
      return true;
   }
   if(PositionGetDouble(POSITION_PRICE_CURRENT) > (PositionGetDouble(POSITION_PRICE_OPEN)+Loss_Operacao)){
      DayTrade.PositionClose(_Symbol);
      saldo_diario += saldo_operacao;
      if(saldo_diario <= -Limite_Loss_Diario || saldo_diario >= Limite_Gain_Diario){
         limite_atingido = true;
      }
      return true;
   } 
   return false;
}

bool HorarioEntrada()
      {
       TimeToStruct(TimeCurrent(),horario_atual);

      if(horario_atual.hour >= horario_inicio.hour && horario_atual.hour <= horario_termino.hour){
      // Hora atual igual a de início
      if(horario_atual.hour == horario_inicio.hour)
         // Se minuto atual maior ou igual ao de início => está no horário de entradas
         if(horario_atual.min >= horario_inicio.min)
            return true;
         // Do contrário não está no horário de entradas
         else
            return false;
      
      // Hora atual igual a de término
      if(horario_atual.hour == horario_termino.hour)
         // Se minuto atual menor ou igual ao de término => está no horário de entradas
         if(horario_atual.min <= horario_termino.min)
            return true;
         // Do contrário não está no horário de entradas
         else
            return false;
      
      // Hora atual maior que a de início e menor que a de término
      return true;
   }
   
   // Hora fora do horário de entradas
   return false;
}


bool HorarioFechamento(){
   TimeToStruct(TimeCurrent(),horario_atual);     
     
     // Hora dentro do horário de fechamento
   if(horario_atual.hour >= horario_fechamento.hour){
      // Hora atual igual a de fechamento
      if(horario_atual.hour == horario_fechamento.hour)
         // Se minuto atual maior ou igual ao de fechamento => está no horário de fechamento
         if(horario_atual.min >= horario_fechamento.min)
            return true;
         // Do contrário não está no horário de fechamento
         else
            return false;
      
      // Hora atual maior que a de fechamento
      return true;
   }
   
   // Hora fora do horário de fechamento
   return false;
}

//Função normalizadora
double NormalizarPreco(double preco){
   //Pegar o tamanho do tick
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize == 0.0){
      return (NormalizeDouble(preco,_Digits));
   }
   
   return(NormalizeDouble(MathRound(preco/tickSize)*tickSize, _Digits));
}
