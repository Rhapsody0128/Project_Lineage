using UtilSystem;
using RoleSystem;

internal class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine(WeaponType.dagger);
        Role person = RoleController.getRandomRole();
        Console.WriteLine(person.name);
    }
}