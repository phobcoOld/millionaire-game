require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController , type: :controller do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  context 'when the user is not logged in' do
    it 'kick from #show' do
      get :show, params: { id: game_w_questions.id }

      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #create' do
      post :create

      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #answer' do
      put :answer, params: { id: 1, letter: 'a' }

      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end

    it 'kick from #take_money' do
      put :take_money, params: { id: 1 }

      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)  
      expect(flash[:alert]).to be
    end

    it 'kick from #help' do
      put :help, params: { id: 1 }

      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(new_user_session_path)  
      expect(flash[:alert]).to be
    end
  end
  
  context 'when user is logged in' do
    before(:each) { sign_in user }

    it 'creates the game' do
      generate_questions(15)

      post :create
      game = assigns(:game)

      expect(game.finished?).to be(false)
      expect(game.user).to eq(user)
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    it '#show game' do
      get :show, params: { id: game_w_questions.id }
      game = assigns(:game) 
      expect(game.finished?).to be(false)
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) 
      expect(response).to render_template('show')
    end

    it 'answers correct' do
      put :answer, params: { id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }
      game = assigns(:game)

      expect(game.finished?).to be(false)
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be(true)
    end

    it '#show alien game' do
      alien_game = FactoryBot.create(:game_with_questions)

      get :show, params: { id: alien_game.id }

      expect(response.status).not_to eq(200)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be
    end

    it 'takes money' do
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, params: { id: game_w_questions.id }
      game = assigns(:game)
      expect(game.finished?).to be(true)
      expect(game.prize).to eq(200)

      user.reload
      expect(user.balance).to eq(200)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    it 'try to create second game' do
      expect(game_w_questions.finished?).to be(false)
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game)
      expect(game).to be_nil

      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end

    it 'call 50/50 help' do
      expect(game_w_questions.fifty_fifty_used).to be(false)
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be

      put :help, params: { id: game_w_questions.id, help_type: :fifty_fifty }
      game = assigns(:game)

      expect(game.fifty_fifty_used).to eq(true)
      expect(game.status).to be(:in_progress)
      expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq(2)
      expect(game.current_game_question.help_hash[:fifty_fifty]).to include(game.current_game_question.correct_answer_key)
      expect(response).to redirect_to(game_path(game))
    end

    context 'and the answer is wrong' do
      it 'finishes the game with fail status' do
        put :answer, params: { id: game_w_questions.id, letter: 'a' }
        game = assigns(:game)

        expect(game.status).to be(:fail)
        expect(game.finished?).to be(true)
      end

      it 'redirect to user path with alert message' do
        put :answer, params: { id: game_w_questions.id, letter: 'a' }
        game = assigns(:game)

        expect(response).to redirect_to(user_path(user))
        expect(flash[:alert]).to be
      end
    end
  end
end
