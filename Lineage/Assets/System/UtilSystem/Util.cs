using System;
using Newtonsoft.Json;

namespace UtilSystem
{
    public class Util
    {
        //取得隨機數(整數)
        public static int getRandom(int min, int max)
        {
            return new Random().Next(min, max);
        }
        //取得隨機數(小數)
        public static double getRandom(double min, double max)
        {
            var random = new Random().NextDouble() * (max - min) + min;
            var result = Math.Round(random, 2, MidpointRounding.AwayFromZero);
            return result;
        }
        //取得隨機數列舉(Enum)
        public static T getRandomFromEnum<T>()
        {
            var values = Enum.GetNames(typeof(T));
            var randonValue = values[getRandom(0, values.Length - 1)];
            return (T)Enum.Parse(typeof(T), randonValue);
        }
        //複製一份unbind
        public static T clone<T>(T obj)
        {
            string json = JsonConvert.SerializeObject(obj);
            var result = JsonConvert.DeserializeObject<T>(json);
            if (result != null) {
                return result;
            }
            else {
                return obj;
            }
        }
    }

}