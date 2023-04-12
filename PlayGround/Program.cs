using UtilSystem;
using RoleSystem;
using RegimentSystem;

internal class Program
{
    private static void Main(string[] args)
    {
        var regiment = RegimentController.getRandomRegiment();
        Console.WriteLine("regiment strength:" + regiment.strength);
        regiment.battalions.ForEach(battalion =>
        {
            Console.WriteLine("battalion strength:" + battalion.strength);
            Console.WriteLine("leader strength:" + battalion.leader.strength);
            battalion.troops.ForEach(troop =>
            {
                Console.WriteLine("troop strength:" + troop.strength);
            });
        });
    }
}