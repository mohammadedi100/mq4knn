//+------------------------------------------------------------------+
//|                                                     KNN(1).mq4   |
//|                                                 Leonardo Guercio |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Leonardo Guercio"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#define MAGICEX  20131111
//--- input parameters
input int          PERIOD = 20;           // averaging period
input int          PERIODMO = 3;          // Momentum period
input double       DEV = 2.0;        // standard deviations
input double       LOTS = 1.0;
input int          k = 15;           // K optimizable
input int          SL = 20;
input int          TP = 60;
// GLOBAL VARS
double BBU, BBD, SMA, MOMENTUM, BBtotal;
int res;

//+------------------------------------------------------------------+
//| KNN                                                              |
//+------------------------------------------------------------------+

// Variables de KNN

double neighbors[][10];
double clases[];
double votes[][2];
 
// Métodos

double EuclidianDistance(double& a[], double& b[], int length){
   double resultado = 0.0;
   for(int i = 0;i<length;i++)
     {
      resultado += MathPow((a[i]-b[i]),2);
     }

   return MathSqrt(resultado);
        
 }

//--- KNN total, usa KNNPredict
 
double KNN(double& data[][], double& predict[], int neigh){
   if(ArrayRange(data,0)<=neigh){
      Print("OJO: el número de datos es menor a K");
   }
   int length = ArraySize(predict)-1;
   double distances[][10];
   int resize = ArrayRange(data,0);
   ArrayResize(distances,resize);     
   for(int i=0;i<ArrayRange(data,0);i++)
   {
      for(int j=0;j<ArrayRange(data,1);j++)
       
         {
            int size = ArrayRange(data,1);
            double data_new[1];
            ArrayResize(data_new,size);
            data_new[j] = data[i,j];
            distances[i,j+1] = data[i,j];  
            double dist = EuclidianDistance(predict,data_new,length);
            distances[i,0] = dist;
         }
   }
     
   ArraySort(distances,WHOLE_ARRAY,0,MODE_DESCEND);
   ArrayResize(neighbors,neigh);
   for(int x=0;x<neigh;x++)
   {
      for(int j=1;j<ArrayRange(distances,1);j++)             
         {
          neighbors[x,j-1] = distances[x,j];
         }
    }
	
	return(KNNPrediction(neighbors));

 }

//--- KNNPredict para los neighbors de la data por predecir
 
double KNNPrediction(double& neighbors1[][])
 {
   int filas = ArrayRange(neighbors1,0);
   int classIndex = -1;
   //--- ..la utilidad de "clases" es sobre todo para la quicksearch
   ArrayResize(clases,filas);
   ArrayResize(votes,filas);
  
   for(int i=0;i<ArrayRange(neighbors1,0);i++)
      {
   //--- ..asume que la clase está en la última columna de neighbors
       double response = neighbors1[i,ArrayRange(neighbors1,1)-1];
       ArraySort(clases);
       ArraySort(votes);
	    classIndex = QuickSearch(response,clases);
       if(classIndex != -1)
          {
           votes[classIndex,1] += 1;
          }
       else
          {
           clases[i] = response;
           votes[i,0] = response;
           votes[i,1] = 1;
          }
       }
    
   //--- ..Debo crear InvertedVotes para poder sortiar el arreglo por los votos. PD: qué mal este lenguaje
   double invertedVotes[][2];
   ArrayResize(invertedVotes,filas);
   for(int x=0;x<filas;x++)
      {
       invertedVotes[x,0] = votes[x,1];
       invertedVotes[x,1] = invertedVotes[x,0];
      }
   
   ArraySort(invertedVotes);
   return(invertedVotes[0,1]);
 
 }
 
//--- ..QuickSearch para este caso (ya que el ArrayBsearch no me sirve, de acuerdo a la doc de MQL)
 
int QuickSearch(double element, double& array[]) 
  {
   int    i,j,m=-1;
   double t_double;
//--- search
   i=0;
   j=ArrayRange(array,0)-1;
   while(j>=i)
     {
      //--- ">>1" is quick division by 2
      m=(j+i)>>1;
      if(m<0 || m>=ArrayRange(array,0))
         break;
      t_double=array[m];
      //--- compare with delta
      if(MathAbs(t_double-element)== 0)
         break;
      if(t_double>element)
         j=m-1;
      else
         i=m+1;
     }
//--- position
   return(m);
  }

//+------------------------------------------------------------------+
//| Read data for KNN                                       |
//+------------------------------------------------------------------+

//Variables de lectura
double data_export[1][6];

//--- "Abridor" del archivo CSV

int FileOpener(string filename, string delimiter)
  {
   ResetLastError();
   int filehandle=FileOpen(filename,FILE_READ|FILE_CSV,delimiter);
   if(filehandle!=INVALID_HANDLE)
     {
      Print("FileOpen OK");
      if(FileSize(filehandle)==0)
      {
       Print("Archivo vacío");
       FileClose(filehandle); return(0); 
      }
     }
   else Print("Operation FileOpen failed, error ",GetLastError());
    
   return(filehandle);
  }

//--- LineCounter para determinar dimensin de la data

int LineCounter(string filename)
  {
   int line_counter = 0;
   int filehandle=FileOpener(filename,"\n");
   while(true)
   {
    string   line = FileReadString(filehandle);
    if(line == "") break; // EOF
    line_counter++;
   }
	//--- close the file
   FileClose(filehandle);
    
   return(line_counter);
  }	

//--- Lectura del archivo CSV

void ReadData(string filename)
  {

	int num_lines = LineCounter(filename);
	//Print("numero de lineas de archivo: "+num_lines); //para debug
	ArrayResize(data_export,num_lines);
   
   int filehandle= FileOpener(filename,",");
   int columnas = 4;     
   if(filehandle>0)
     {                                         
      int line=0;
    
      while(FileTell(filehandle)< FileSize(filehandle))  //<-- FileIsEnding is buggy and does never return true
      {        
         for(int i=0;i<columnas;i++)
         {                     
          data_export[line,i]=double(FileReadString(filehandle));     //    Use FileTell and FileSize instead (https://forum.mql4.com/52640)
          // Print("Dato exportada: "+data_export[line,i]); debug
         }   
         line++;                                         
         if(line==num_lines)break;      
      }

	//--- close the file

    FileClose(filehandle);
   }

  }

//+------------------------------------------------------------------+
//| Calculate open positions (esto ya estaba aqui). Igual no lo usé  |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol)
  {
   int buys=0,sells=0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICEX)
        {
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
        }
     }
	//--- return orders volume
   if(buys>0) return(buys);
   else       return(-sells);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   
   ReadData("data.csv");
     

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

void CheckForOpen()
  {
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
//---SMA
   SMA = iMA(NULL,0,PERIOD,8,0,PRICE_CLOSE,0);
   SMA = SMA - 1.0;
//---Bollinger Bands
   BBU = CustomBollinger(PERIOD); 
//---MOMENTUM, usando fórmula
   MOMENTUM = CustomMomentum(PERIODMO); // integrada: MOMENTUM = iMomentum(NULL,0,PERIODMO,PRICE_CLOSE,0);
//--- creating predict feature
   double feature[3];
   feature[0] = MOMENTUM;
   feature[1] = SMA;
   feature[2] = BBU;
  //Print("el arreglo es: Momentum: "+feature[0]+", SMA: "+feature[1]+", BB: "+feature[2]); //Debug
//--- sell conditions
   if(KNN(data_export,feature,k) == 2.0)
     {
      res=OrderSend(Symbol(),OP_SELL,LOTS,Bid,3,SL,TP,"",MAGICEX,0,Red);
      return;
     }
//--- buy conditions
   if(KNN(data_export,feature,k) == 1.0)
     {
      res=OrderSend(Symbol(),OP_BUY,LOTS,Ask,3,SL,TP,"",MAGICEX,0,Blue);
      return;
     }
   else(Print("Mixed conditions, wait for next candle"));
//---
  }
  
double CustomMomentum(int period)
  {
   double result = (Close[1]/Close[1+period])-1.0;
   return result;
  }
  
 double CustomBollinger(int period)
  {
     double standardDeviation = 0.0;
     double num = 0.0;
     for(int i=1;i<period+1;i++)
       {          
        num += (Close[1]-Close[1+i]); // media standard... Creo.
       }
      num = num/period;
     for(int i = 1; i <= period; ++i)
      {
       standardDeviation += pow(Close[i] - num, 2);
      }
     double sd = sqrt(standardDeviation/period);
     return(num/(2*sd));
  }
  
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckForOpen();
  }
  
//+-------------------------------------------------------------
//sin stoch: PER:18, DEV:1, LOTS:6, ATRFrac:2.5, ATRPeriod:26(GBP a 30)
