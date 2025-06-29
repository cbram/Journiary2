const bcrypt = require('bcryptjs');
const { AppDataSource } = require('./src/utils/database');
const { User } = require('./src/entities/User');

async function debugAuth() {
    try {
        // Initialize database connection
        console.log('🔍 Connecting to database...');
        await AppDataSource.initialize();
        console.log('✅ Database connected!');

        // Find all users
        const userRepository = AppDataSource.getRepository(User);
        const allUsers = await userRepository.find();
        
        console.log('\n📋 All users in database:');
        allUsers.forEach((user, index) => {
            console.log(`${index + 1}. ID: ${user.id}`);
            console.log(`   Email: ${user.email}`);
            console.log(`   Password Hash: ${user.password.substring(0, 30)}...`);
            console.log(`   Created: ${user.createdAt}`);
            console.log('');
        });

        // Check specific user
        const targetEmail = 'chbram@mailbox.org';
        const targetPassword = 'C0mp1Fu-.y';
        
        console.log(`🔍 Looking for user: ${targetEmail}`);
        const user = await userRepository.findOneBy({ email: targetEmail });
        
        if (user) {
            console.log('✅ User found!');
            console.log('📋 User details:');
            console.log(`   ID: ${user.id}`);
            console.log(`   Email: ${user.email}`);
            console.log(`   Current Hash: ${user.password}`);
            
            // Test password comparison
            console.log(`\n🔐 Testing password: "${targetPassword}"`);
            const isValid = await bcrypt.compare(targetPassword, user.password);
            console.log(`   Password valid: ${isValid}`);
            
            if (!isValid) {
                console.log('\n🔧 Creating new hash for correct password...');
                const newHash = await bcrypt.hash(targetPassword, 12);
                console.log(`   New hash: ${newHash}`);
                
                // Update user with correct password hash
                console.log('\n💾 Updating user with correct password hash...');
                user.password = newHash;
                await userRepository.save(user);
                console.log('✅ User password updated!');
                
                // Verify the update worked
                console.log('\n🔍 Verifying update...');
                const updatedUser = await userRepository.findOneBy({ email: targetEmail });
                const verifyValid = await bcrypt.compare(targetPassword, updatedUser.password);
                console.log(`   Password now valid: ${verifyValid}`);
            }
        } else {
            console.log('❌ User not found!');
            console.log('\n🔧 Creating new user...');
            
            const hashedPassword = await bcrypt.hash(targetPassword, 12);
            const newUser = userRepository.create({
                email: targetEmail,
                password: hashedPassword,
            });
            
            await userRepository.save(newUser);
            console.log('✅ New user created!');
            console.log(`   ID: ${newUser.id}`);
            console.log(`   Email: ${newUser.email}`);
        }

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        // Close database connection
        if (AppDataSource.isInitialized) {
            await AppDataSource.destroy();
            console.log('\n🔌 Database connection closed');
        }
    }
}

// Run the debug function
debugAuth().catch(console.error); 