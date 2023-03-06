using System;
using CharacterSystem;


public class MyMainClass {
    static void Main(string[] args) {
        Character person = new Character("apple");
        string name = person.getName();
        Console.WriteLine(person);
        Console.WriteLine(name);
        Console.WriteLine("name");
    }
}