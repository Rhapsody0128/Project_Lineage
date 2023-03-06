// using Potential;

namespace CharacterSystem {
    public class Character {
        private Guid id ;
        private string name ;
        // private potential potential ;
        
        public Character(string CharacterName){
            name = CharacterName;
            Guid id = Guid.NewGuid();
            
        }
        
        public string getName(){
            return name;
        }
    }
}