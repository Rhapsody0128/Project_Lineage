namespace UtilSystem {

    
    public class Util {
        public static int getRandom(int min,int max){
            return new Random().Next(min,max);
        }
        public static double getRandom(double min, double max){ 
            var random = new Random().NextDouble() * (max - min) + min;
            var result = Math.Round(random, 2, MidpointRounding.AwayFromZero);
            return result ;
        }
        public static T getRandomFromEnum<T>(){
            var values = Enum.GetNames(typeof(T)) ;
            var randonValue = values[getRandom(0,values.Length-1)] ;
            return (T)Enum.Parse(typeof(T), randonValue) ;
        }


    }
}